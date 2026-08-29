#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DATA_DIR="$SCRIPT_DIR/data"
DRY_RUN=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [--dry-run] [--data-dir PATH]

Normalizes the cocktail and ingredient catalogs by:
  - removing trailing _NUMBER folder and ID suffixes
  - updating ingredient and parent-cocktail references
  - converting images to WebP at 80% quality and at most 1000px high
  - renaming images from their catalog folder name
  - setting created_at and updated_at values to null
  - setting ingredient prices to an empty array

When duplicate folder names remain after suffix removal, they are named slug,
slug-2, slug-3, and so on. Use --dry-run to validate and preview the cleanup.
EOF
}

while (($# > 0)); do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            ;;
        --data-dir)
            if (($# < 2)); then
                echo "Error: --data-dir requires a path." >&2
                exit 2
            fi
            DATA_DIR=$2
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3))); then
    echo "Error: Bash 4.3 or newer is required." >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required." >&2
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "Error: ffmpeg with the libwebp encoder is required." >&2
    exit 1
fi

ffmpeg_encoders=$(ffmpeg -hide_banner -encoders 2>/dev/null) || {
    echo "Error: Could not inspect ffmpeg encoders." >&2
    exit 1
}
if [[ $ffmpeg_encoders != *" libwebp "* ]]; then
    echo "Error: ffmpeg must include the libwebp encoder." >&2
    exit 1
fi
unset ffmpeg_encoders

DATA_DIR=$(cd -- "$DATA_DIR" 2>/dev/null && pwd) || {
    echo "Error: Data directory not found: $DATA_DIR" >&2
    exit 1
}

for catalog in cocktails ingredients; do
    if [[ ! -d "$DATA_DIR/$catalog" ]]; then
        echo "Error: Catalog directory not found: $DATA_DIR/$catalog" >&2
        exit 1
    fi
done

declare -a PLAN_SOURCES=()
declare -a PLAN_TARGETS=()
declare -a PLAN_NAMES=()
declare -a PLAN_KINDS=()
declare -a STAGED_JSON=()
declare -A COCKTAIL_IDS=()
declare -A INGREDIENT_IDS=()
declare -A SOURCE_DIRS=()

folder_rename_count=0
image_rename_count=0
image_conversion_count=0
json_update_count=0

strip_export_suffix() {
    local name=$1

    if [[ $name =~ ^(.+)_[0-9]+$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '%s' "$name"
    fi
}

add_id_mapping() {
    local kind=$1 old_id=$2 new_id=$3 existing

    [[ -n $old_id ]] || return 0

    if [[ $kind == cocktails ]]; then
        if [[ -n ${COCKTAIL_IDS["$old_id"]+x} ]]; then
            existing=${COCKTAIL_IDS["$old_id"]}
            [[ $existing == "$new_id" ]] || {
                echo "Error: Cocktail ID '$old_id' maps to both '$existing' and '$new_id'." >&2
                exit 1
            }
        else
            COCKTAIL_IDS["$old_id"]=$new_id
        fi
    else
        if [[ -n ${INGREDIENT_IDS["$old_id"]+x} ]]; then
            existing=${INGREDIENT_IDS["$old_id"]}
            [[ $existing == "$new_id" ]] || {
                echo "Error: Ingredient ID '$old_id' maps to both '$existing' and '$new_id'." >&2
                exit 1
            }
        else
            INGREDIENT_IDS["$old_id"]=$new_id
        fi
    fi
}

plan_catalog() {
    local kind=$1
    local root="$DATA_DIR/$kind"
    local folder source_name base_name target_name target_path json_file current_id
    local duplicate_number
    local -a folders=()
    local -A reserved_names=()
    local -A assigned_names=()

    while IFS= read -r -d '' folder; do
        folders+=("$folder")
        source_name=$(basename -- "$folder")
        reserved_names["$source_name"]=1
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -print0 | sort -zV)

    for folder in "${folders[@]}"; do
        source_name=$(basename -- "$folder")
        base_name=$(strip_export_suffix "$source_name")
        target_name=$base_name
        duplicate_number=2

        while [[ -n ${assigned_names["$target_name"]+x} || (
            $target_name != "$source_name" && -n ${reserved_names["$target_name"]+x}
        ) ]]; do
            target_name="$base_name-$duplicate_number"
            ((duplicate_number += 1))
        done

        assigned_names["$target_name"]=1
        target_path="$root/$target_name"
        json_file="$folder/data.json"

        if [[ ! -f $json_file ]]; then
            echo "Error: Missing catalog file: $json_file" >&2
            exit 1
        fi

        if ! current_id=$(jq -er '
            if type == "object"
                and (._id | type) == "string"
                and (.images | type) == "array"
                and all(.images[]; type == "object" and (.uri | type) == "string")
            then ._id
            else error("invalid catalog object")
            end
        ' "$json_file"); then
            echo "Error: Invalid catalog JSON: $json_file" >&2
            exit 1
        fi

        add_id_mapping "$kind" "$source_name" "$target_name"
        add_id_mapping "$kind" "$current_id" "$target_name"

        PLAN_SOURCES+=("$folder")
        PLAN_TARGETS+=("$target_path")
        PLAN_NAMES+=("$target_name")
        PLAN_KINDS+=("$kind")
        SOURCE_DIRS["$folder"]=1

        if [[ $folder != "$target_path" ]]; then
            ((folder_rename_count += 1))
        fi
    done
}

plan_catalog cocktails
plan_catalog ingredients

for target_path in "${PLAN_TARGETS[@]}"; do
    if [[ -e $target_path && -z ${SOURCE_DIRS["$target_path"]+x} ]]; then
        echo "Error: Refusing to overwrite unrelated path: $target_path" >&2
        exit 1
    fi
done

declare -a IMAGE_SOURCES=()
declare -a IMAGE_TARGETS=()
declare -a IMAGE_NAMES=()

load_images() {
    local plan_index=$1
    local folder=${PLAN_SOURCES[plan_index]}
    local folder_name=${PLAN_NAMES[plan_index]}
    local json_file="$folder/data.json"
    local image_count index uri source_name target_name

    IMAGE_SOURCES=()
    IMAGE_TARGETS=()
    IMAGE_NAMES=()
    image_count=$(jq -r '.images | length' "$json_file")

    for ((index = 0; index < image_count; index++)); do
        uri=$(jq -r --argjson index "$index" '.images[$index].uri' "$json_file")
        source_name=${uri#file:///}

        if ((image_count == 1)); then
            target_name="$folder_name.webp"
        else
            target_name="$folder_name-$((index + 1)).webp"
        fi

        IMAGE_SOURCES+=("$folder/$source_name")
        IMAGE_TARGETS+=("$folder/$target_name")
        IMAGE_NAMES+=("$target_name")
    done
}

preflight_images() {
    local plan_index=$1
    local folder=${PLAN_SOURCES[plan_index]}
    local json_file="$folder/data.json"
    local index uri source_name source_path target_path file
    local -A source_files=()
    local -A target_files=()

    load_images "$plan_index"

    for ((index = 0; index < ${#IMAGE_SOURCES[@]}; index++)); do
        uri=$(jq -r --argjson index "$index" '.images[$index].uri' "$json_file")
        source_name=${uri#file:///}
        source_path=${IMAGE_SOURCES[index]}
        target_path=${IMAGE_TARGETS[index]}

        if [[ $uri != file:///* || -z $source_name || $source_name == */* ||
            $source_name == .* || $source_name != *.* || $source_name == *$'\n'* ]]; then
            echo "Error: Unsafe or unsupported image URI '$uri' in $json_file" >&2
            exit 1
        fi
        if [[ ! -f $source_path ]]; then
            echo "Error: Referenced image not found: $source_path" >&2
            exit 1
        fi
        if [[ -n ${source_files["$source_path"]+x} ]]; then
            echo "Error: Image is referenced more than once: $source_path" >&2
            exit 1
        fi
        if [[ -n ${target_files["$target_path"]+x} ]]; then
            echo "Error: Multiple images would be renamed to: $target_path" >&2
            exit 1
        fi

        source_files["$source_path"]=1
        target_files["$target_path"]=1
        ((image_conversion_count += 1))

        if [[ $source_path != "$target_path" ]]; then
            ((image_rename_count += 1))
        fi
    done

    while IFS= read -r -d '' file; do
        if [[ -z ${source_files["$file"]+x} ]]; then
            echo "Error: Unreferenced file in catalog folder: $file" >&2
            exit 1
        fi
    done < <(find "$folder" -mindepth 1 -maxdepth 1 -type f ! -name data.json -print0)

    for target_path in "${IMAGE_TARGETS[@]}"; do
        if [[ -e $target_path && -z ${source_files["$target_path"]+x} ]]; then
            echo "Error: Refusing to overwrite unrelated file: $target_path" >&2
            exit 1
        fi
    done
}

for ((plan_index = 0; plan_index < ${#PLAN_SOURCES[@]}; plan_index++)); do
    preflight_images "$plan_index"
done

map_to_json() {
    local -n id_map=$1
    local key

    for key in "${!id_map[@]}"; do
        printf '%s\t%s\n' "$key" "${id_map[$key]}"
    done | jq -Rn '
        reduce inputs as $line ({};
            ($line | split("\t")) as $pair
            | .[$pair[0]] = $pair[1]
        )
    '
}

cocktail_ids_json=$(map_to_json COCKTAIL_IDS)
ingredient_ids_json=$(map_to_json INGREDIENT_IDS)
staging_dir=$(mktemp -d)
trap 'rm -rf -- "$staging_dir"' EXIT

for ((plan_index = 0; plan_index < ${#PLAN_SOURCES[@]}; plan_index++)); do
    folder=${PLAN_SOURCES[plan_index]}
    target_name=${PLAN_NAMES[plan_index]}
    kind=${PLAN_KINDS[plan_index]}
    json_file="$folder/data.json"
    staged_json="$staging_dir/$plan_index.json"

    load_images "$plan_index"
    if ((${#IMAGE_NAMES[@]} > 0)); then
        image_names_json=$(printf '%s\0' "${IMAGE_NAMES[@]}" | jq -Rs 'split("\u0000")[:-1]')
    else
        image_names_json='[]'
    fi

    if ! jq --indent 4 \
        --arg kind "$kind" \
        --arg new_id "$target_name" \
        --argjson cocktail_ids "$cocktail_ids_json" \
        --argjson ingredient_ids "$ingredient_ids_json" \
        --argjson image_names "$image_names_json" '
        def mapped($ids):
            if type == "string" then
                ($ids[.] // sub("_[0-9]+$"; ""))
            else
                .
            end;

        walk(
            if type == "object" then
                (if has("created_at") then .created_at = null else . end)
                | (if has("updated_at") then .updated_at = null else . end)
            else
                .
            end
        )
        | if $kind == "cocktails" then
            walk(
                if type == "object" and has("_id") then
                    ._id |= mapped($ingredient_ids)
                else
                    .
                end
            )
            | if has("parent_cocktail_id") then
                .parent_cocktail_id |= mapped($cocktail_ids)
              else
                .
              end
          else
            walk(
                if type == "object" then
                    (if has("_id") then ._id |= mapped($ingredient_ids) else . end)
                    | (if has("_parent_id") then ._parent_id |= mapped($ingredient_ids) else . end)
                    | (if has("prices") then .prices = [] else . end)
                else
                    .
                end
            )
          end
        | ._id = $new_id
        | .images |= (
            to_entries
            | map(.value.uri = ("file:///" + $image_names[.key]) | .value)
        )
    ' "$json_file" > "$staged_json"; then
        echo "Error: Could not normalize $json_file" >&2
        exit 1
    fi

    chmod --reference="$json_file" "$staged_json"
    STAGED_JSON+=("$staged_json")
    if ! cmp -s -- "$json_file" "$staged_json"; then
        ((json_update_count += 1))
    fi
done

echo "Catalog entries: ${#PLAN_SOURCES[@]}"
echo "Folders to rename: $folder_rename_count"
echo "Images to rename: $image_rename_count"
echo "Images to convert: $image_conversion_count"
echo "JSON files to update: $json_update_count"

if $DRY_RUN; then
    echo "Dry run complete; no files were changed."
    exit 0
fi

# Convert every image before modifying the catalog so a conversion failure leaves
# all source files intact.
for ((plan_index = 0; plan_index < ${#PLAN_SOURCES[@]}; plan_index++)); do
    load_images "$plan_index"

    for ((image_index = 0; image_index < ${#IMAGE_SOURCES[@]}; image_index++)); do
        source_path=${IMAGE_SOURCES[image_index]}
        staging_path="$staging_dir/image-$plan_index-$image_index.webp"

        if ! ffmpeg -nostdin -hide_banner -loglevel error -y \
            -i "$source_path" \
            -vf "scale=-1:'min(1000,ih)':flags=lanczos" \
            -frames:v 1 -c:v libwebp -quality 80 \
            "$staging_path"; then
            echo "Error: Could not convert image: $source_path" >&2
            exit 1
        fi

        chmod --reference="$source_path" "$staging_path"
    done
done

for ((plan_index = 0; plan_index < ${#PLAN_SOURCES[@]}; plan_index++)); do
    folder=${PLAN_SOURCES[plan_index]}
    json_file="$folder/data.json"
    staged_json=${STAGED_JSON[plan_index]}
    load_images "$plan_index"

    for ((image_index = 0; image_index < ${#IMAGE_SOURCES[@]}; image_index++)); do
        source_path=${IMAGE_SOURCES[image_index]}
        rm -- "$source_path"
    done

    for ((image_index = 0; image_index < ${#IMAGE_SOURCES[@]}; image_index++)); do
        target_path=${IMAGE_TARGETS[image_index]}
        staging_path="$staging_dir/image-$plan_index-$image_index.webp"
        mv -- "$staging_path" "$target_path"
    done

    if ! cmp -s -- "$json_file" "$staged_json"; then
        mv -- "$staged_json" "$json_file"
    fi
done

declare -a FOLDER_STAGING_PATHS=()
for ((plan_index = 0; plan_index < ${#PLAN_SOURCES[@]}; plan_index++)); do
    source_path=${PLAN_SOURCES[plan_index]}
    target_path=${PLAN_TARGETS[plan_index]}
    staging_path="$(dirname -- "$source_path")/.cleanup-folder.$$.$plan_index"
    FOLDER_STAGING_PATHS+=("$staging_path")

    if [[ $source_path != "$target_path" ]]; then
        [[ ! -e $staging_path ]] || {
            echo "Error: Folder staging path already exists: $staging_path" >&2
            exit 1
        }
        mv -- "$source_path" "$staging_path"
    fi
done

for ((plan_index = 0; plan_index < ${#PLAN_SOURCES[@]}; plan_index++)); do
    source_path=${PLAN_SOURCES[plan_index]}
    target_path=${PLAN_TARGETS[plan_index]}
    if [[ $source_path != "$target_path" ]]; then
        mv -- "${FOLDER_STAGING_PATHS[plan_index]}" "$target_path"
    fi
done

echo "Cleanup complete."

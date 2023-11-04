# Bar Assistant Public Data

This is initial data that gets imported when creating a new bar in Bar Assistant

WIP

## Data structure

To make it easier to write recipes by hand and at the same time handle merge requests the choice of recipe format is YAML in single files.

TODO: Validate via JSON schema

- Every recipe should have a unique filename, [usually as slug of the cocktail name](https://stackoverflow.com/questions/19335215/what-is-a-slug).
- For data integrity, you can use this unqiue `_id` reference when writing recipes to reference other data (like ingredients, glass types, methods...).
- Recipe images are stored in `images` folder located in the same folder as the `.yml` files.
- You can add multiple images and reference them by their filename when adding a new recipe.
- It's recommended that you add images as the following filename format: `{recipe_slug}-{image-number}.{extension}`, for example: `old_fashioned-1.jpg`, `old_fashioned-2.webp`, `gin-1.png`.
- All images must have copyright information, preferebly author of the image. For example: `Punch | John Doe`, `Imbibe magazine`, `Salvador Dali`

### New ingredients

To add a new ingredient you need to edit `base_ingredients.yml` file. Here's an example new entry:

```yaml
- name: My new ingredient
  category: Liqueurs
  strength: 40
  description: A short description
  color: '#00ff00'
  origin: Croatia
  images:
    - resource_path: ingredients/my-new-ingredient.png
      copyright: Wikipedia
      placeholder_hash: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
```

- Please note that category with given name must already exist in `base_ingredient_categories.yml`.
- Images are optional
- If you do add an image, name image file in kebab case and put it in `data/ingredients` folder
- You can use any string for `placeholder_hash`, this will be populated via optimization step

## Optimization

Ingredient optimization includes:
- Clamp to max height of 600
- Trim empty space around image
- Generate `placeholder_hash` with thumbhash

Cocktail optimization includes:
- Compress image with 90% quality

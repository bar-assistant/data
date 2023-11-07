# Bar Assistant Public Data

This is data that gets imported when creating a new bar in Bar Assistant.

Still WIP:
- Add and validate via JSON schema
- Make image optimizations stable

## Data structure

To make it easier to write recipes by hand and at the same time handle merge requests / importing the choice of recipe format is YAML in single files.

- Every recipe should have a unique filename, [usually a slug of the cocktail name](https://stackoverflow.com/questions/19335215/what-is-a-slug).
- For data integrity, you can use this filename as unqiue `_id` reference when writing recipes to reference other data (like ingredients, glass types, methods...).
- Recipe images are stored in `images` folder located in the same folder as the `.yml` files.
- You can add multiple images and reference them by their filename when adding a new recipe.
- It's recommended that you add images as the following filename format: `{recipe_slug}-{image-number}.{extension}`, for example: `old_fashioned-1.jpg`, `old_fashioned-2.webp`, `gin-1.png`.
- All images must have copyright information, preferebly author of the image. For example: `Punch | John Doe`, `Imbibe magazine`, `Salvador Dali`

## Contributing

TODO

### Cocktail tags

Use tags that make sense to the recipe, try to keep total tags between 1 and 5. Some examples:

By taste:
- Bright
- Bitter
- Herbacious
- Citrusy
- Fruity
- Floral
- Savory
- Smokey
- Spicy
- Sweet
- Tart

By riff/type:
- Negroni
- Manhattan
- Old fashioned
- Sour
- Flip
- Spritz
- Fizz
- Cooler
- Frozen
- Julep
- Swizzle

Other common ones:
- Summer
- Winter
- Tiki
- Virgin
- Wine

## Image manipulation

For data to be more consisted we include image optimization script. Any entry that does not have `placeholder_hash` will be run through this optimization. This step will update the .yml file at the end.

Ingredient optimization includes:
- Clamp to max height of 600
- Trim empty space around image
- Compress the image
- Downgrade to 80% of image quality
- Generate `placeholder_hash` with thumbhash

Cocktail optimization includes:
- Clamp to max height of 1400
- Compress image with 80% quality
- Use mozjpeg defaults
- Generate `placeholder_hash` with thumbhash

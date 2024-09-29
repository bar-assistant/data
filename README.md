# Bar Assistant Public Data

This is default data that gets imported when creating a new bar in Bar Assistant.

## Data structure

Data structure is defined by JSON schema.

- Every recipe should have a unique folder name, [usually a slug of the cocktail name](https://stackoverflow.com/questions/19335215/what-is-a-slug).
- For data integrity, you can use this folder name as unqiue `_id` reference when writing recipes to reference other data (like ingredients, glass types, methods...).
- Images related to the recipe are stored in the root folder of the recipe.
- You can add multiple images and reference them by their filename when adding a new recipe.
- It's recommended that you add images as the following filename format: `{recipe_slug}-{image-number}.{extension}`, for example: `old_fashioned-1.jpg`, `old_fashioned-2.webp`, `gin-1.png`.
- All images must have copyright information, preferebly author of the image. For example: `Punch | John Doe`, `Imbibe magazine`, `Salvador Dali`

## Contributing

Merge requests with new recipes suggestions, or recipe edits are welcome.

### Cocktail tags

Use tags that make sense to the recipe, try to keep total tags between 1 and 5. Some examples:

- By taste: `Bright`, `Bitter`, `Herbacious`, `Citrusy`, `Fruity`, `Floral`, `Savory`, `Smokey`, `Spicy`, `Sweet`, `Tart`
- By riff/type: `Negroni`, `Manhattan`, `Old fashioned`, `Sour`, `Flip`, `Spritz`, `Fizz`, `Cooler`, `Frozen`, `Julep`, `Swizzle`
- Other common ones: `Summer`, `Winter`, `Tiki`, `Virgin`, `Wine`

## Image guidelines

These are strong suggestions, but not mandatory.

Ingredient images:
- Use transparent background WebP image of the ingredient
- Clamp to max height of 600
- Trim empty space around image
- Compress the image
- Downgrade to 80% of image quality

Cocktail images:
- Use WebP format
- Clamp to max height of 1400
- Compress image with 80% quality

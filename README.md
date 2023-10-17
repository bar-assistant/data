# Bar Assistant Public Data

This is initial data that gets imported when creating a new bar in Bar Assistant

## Contributing

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

# Bar Assistant Public Data

This is initial data that gets imported when creating a new bar in Bar Assistant

## Contributing

TODO

## Optimization

Optimize ingredient images:
- Clamp to max height of 600
- Trim empty space around image

```bash
docker run -v $(pwd)/data:/data --rm -it bassdata sharp -i './ingredients/*.png' -o ./ingredients trim -- resize --height 600
```

const sharp = require('sharp');
const fs = require('fs/promises')
const yml = require('yaml');
var crypto = require("crypto");

const dataFolder = process.cwd() + '/data/';
const tempFolder = process.cwd() + '/data/temp/';

const processIngredientImages = async () => {
    const file = await fs.readFile(dataFolder + '/base_ingredients.yml', 'utf8')
    const fileIngredients = yml.parse(file)

    await Promise.all(fileIngredients.map(async ing => {
        if (Array.from(ing.images).length > 0) {
            await Promise.all(ing.images.map(async img => {
                const filename = `${dataFolder}${img.resource_path}`
                const tempFilename = `${tempFolder}${crypto.randomBytes(20).toString('hex')}`

                sharp(filename)
                    .resize(null, 600, {
                        withoutEnlargement: true
                    })
                    .trim()
                    .png()
                    .toFile(tempFilename)
                    .then(() => fs.rename(tempFilename, `${filename}`));

                const thumbhash = await import('thumbhash');
                const buffer = await sharp(filename)
                    .resize(80, 80)
                    .raw()
                    .toBuffer();
                const pixelArray = new Uint8ClampedArray(buffer);

                const hash = thumbhash.rgbaToThumbHash(80, 80, pixelArray);
                img.placeholder_hash = btoa(String.fromCharCode(...hash)).replace(/=+$/, '');

                return img
            }))
        }

        return ing;
    }))

    const newYaml = yml.stringify(fileIngredients, {
        lineWidth: 0,
        singleQuote: true
    })

    await fs.writeFile(process.cwd() + '/data/base_ingredients.yml', newYaml)
}

const processCocktailImages = async () => {
    const folder = process.cwd() + '/data/cocktails/';
    const files = await fs.readdir(folder)

    files.map(async (filename) => {
        const tempFilename = `${folder}temp-${filename}`
        sharp(`${folder}${filename}`)
            .jpeg({
                quality: 80
            })
            .toFile(tempFilename)
            .then(() => fs.rename(tempFilename, `${folder}${filename}`));
    })
}

// processCocktailImages()
processIngredientImages()

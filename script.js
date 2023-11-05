const sharp = require('sharp');
const fs = require('fs/promises')
const yml = require('yaml');
var crypto = require("crypto");

const dataFolder = process.cwd() + '/data/';
const tempFolder = process.cwd() + '/data/temp/';

const processIngredientImages = async () => {
    const ingredientFiles = await fs.readdir(dataFolder + 'ingredients', {
        withFileTypes: true
    });

    for (let i = 0; i < ingredientFiles.length; i++) {
        if (!ingredientFiles[i].isFile()) {
            continue;
        }

        const file = await fs.readFile(dataFolder + '/ingredients/' + ingredientFiles[i].name, 'utf8')
        const ing = yml.parse(file)

        if (ing.images && Array.from(ing.images).length > 0) {
            await Promise.all(ing.images.map(async img => {
                const filename = `${dataFolder}ingredients/images/${img.file_name}`
                const tempFilename = `${tempFolder}${crypto.randomBytes(20).toString('hex')}`
                console.log(`processing ${filename}...`)

                // sharp(filename)
                //     .resize(null, 600, {
                //         withoutEnlargement: true
                //     })
                //     .trim()
                //     .png({
                //         compressionLevel: 9,
                //         quality: 80
                //     })
                //     .toFile(tempFilename)
                //     .then(() => fs.rename(tempFilename, `${filename}`));

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

            const newYaml = yml.stringify(ing, {
                indent: 4,
                lineWidth: 0,
                singleQuote: true
            })

            await fs.writeFile(dataFolder + '/ingredients/' + ingredientFiles[i].name, newYaml)
        }
    }

    // await fs.writeFile(process.cwd() + '/data/base_ingredients.yml', newYaml)
}

const processCocktailImages = async () => {
    const folder = process.cwd() + '/data/cocktails/images/';
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

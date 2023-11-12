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

        const file = await fs.readFile(dataFolder + 'ingredients/' + ingredientFiles[i].name, 'utf8')
        const ing = yml.parse(file)

        if (ing.images && Array.from(ing.images).length > 0) {
            await Promise.all(ing.images.map(async img => {
                const filename = `${dataFolder}ingredients/images/${img.file_name}`
                const tempFilename = `${tempFolder}${crypto.randomBytes(20).toString('hex')}`

                if (img.placeholder_hash == null) {
                    console.log(`Processing ingredient ${filename}...`)
                    sharp(filename)
                        .resize(null, 600, {
                            withoutEnlargement: true
                        })
                        .trim()
                        .png({
                            compressionLevel: 9,
                            quality: 80
                        })
                        .toFile(tempFilename)
                        .then(() => fs.rename(tempFilename, `${filename}`));

                    img.placeholder_hash = await getHash(filename);
                }

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
}

const processCocktailImages = async () => {
    const cocktailFiles = await fs.readdir(dataFolder + 'cocktails', {
        withFileTypes: true
    });

    for (let i = 0; i < cocktailFiles.length; i++) {
        if (!cocktailFiles[i].isFile()) {
            continue;
        }

        const file = await fs.readFile(dataFolder + '/cocktails/' + cocktailFiles[i].name, 'utf8')
        const cocktail = yml.parse(file)

        if (cocktail && cocktail.images && Array.from(cocktail.images).length > 0) {
            await Promise.all(cocktail.images.map(async img => {
                const filename = `${dataFolder}cocktails/images/${img.file_name}`
                const tempFilename = `${tempFolder}${crypto.randomBytes(20).toString('hex')}`

                if (img.placeholder_hash == null) {
                    console.log(`Processing cocktail ${filename}...`)
                    sharp(filename)
                        .jpeg({
                            quality: 80,
                            mozjpeg: true
                        })
                        .resize(null, 1400, {
                            withoutEnlargement: true
                        })
                        .toFile(tempFilename)
                        .then(() => fs.rename(tempFilename, `${filename}`));

                    img.placeholder_hash = await getHash(filename);
                }

                return img
            }))

            const newYaml = yml.stringify(cocktail, {
                indent: 4,
                lineWidth: 0,
                singleQuote: true
            })

            await fs.writeFile(dataFolder + '/cocktails/' + cocktailFiles[i].name, newYaml)
        }
    }
}

const getHash = async (filename) => {
    console.log(filename)
    const thumbhash = await import('thumbhash');
    const {data, info} = await sharp(filename)
        .ensureAlpha()
        .resize({
            width: 100,
            height: 100,
            fit: 'inside',
        })
        .raw()
        .toBuffer({ resolveWithObject: true });

    const hash = thumbhash.rgbaToThumbHash(info.width, info.height, data);

    return btoa(String.fromCharCode(...hash)).replace(/=+$/, '');
}

processCocktailImages()
processIngredientImages()

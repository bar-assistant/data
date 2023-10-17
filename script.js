const sharp = require('sharp');
const fs = require('fs/promises')

const processIngredientImages = async () => {
    const folder = process.cwd() + '/data/ingredients/';
    const files = await fs.readdir(folder)

    files.map(async (filename) => {
        const tempFilename = `${folder}temp-${filename}`
        sharp(`${folder}${filename}`)
            .resize(null, 600, {
                withoutEnlargement: true
            })
            .trim()
            .png()
            .toFile(tempFilename)
            .then(() => fs.rename(tempFilename, `${folder}${filename}`));

        // const thumbhash = await import('thumbhash');
        // const buffer = await sharp(`${folder}${filename}`)
        //     .resize(80, 80)
        //     .raw()
        //     .toBuffer();
        // const pixelArray = new Uint8ClampedArray(buffer);

        // const hash = thumbhash.rgbaToThumbHash(80, 80, pixelArray);
        // console.log(btoa(String.fromCharCode(...hash)).replace(/=+$/, ''))
    })
}

processIngredientImages()

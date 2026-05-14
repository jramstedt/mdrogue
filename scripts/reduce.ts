import {readFile, writeFile} from 'node:fs/promises'
import {basename, dirname, extname, resolve} from 'node:path'
import {decode, encode} from 'fast-png'
import {distance, image, palette, utils} from 'image-q'
import {imageQPalette, imageQPalette as megaDrivePalette} from './megadrive.ts'
import {getIndexArray} from './utils.ts'

const [,, imageFilename, colorCountArg] = process.argv

if (imageFilename === undefined || imageFilename.length === 0) {
  console.error('Image filename missing.')
  process.exit(1)
}

const colorCount = colorCountArg !== undefined && colorCountArg.length >0 ? parseInt(colorCountArg) : 16
if (isNaN(colorCount)) {
  console.error(`Unsupported color count ${colorCountArg}.`)
  process.exit(1)
}

const imagePath = resolve(imageFilename)

const decodedImage = decode(await readFile(imagePath), { checkCrc: true })
const { width: imageWidth, height: imageHeight, channels: imageChannels, depth: imageDepth, data: imagePixels, palette: imagePalette } = decodedImage

if (imageDepth !== 8 || imagePixels instanceof Uint16Array) {
  console.error(`Unsupported color depth ${imageDepth} (${typeof imagePixels}).`)
  process.exit(1)
}

if (imageChannels !== 4 && imageChannels !== 1) {
  console.error(`Unsupported channels ${imageChannels}.`)
  process.exit(1)
}

let imagePointContainer: utils.PointContainer
if (imageChannels === 4) {
  imagePointContainer = utils.PointContainer.fromUint8Array(
    imagePixels,
    imageWidth,
    imageHeight,
  );
} else {
  if (imagePalette === undefined) {
    console.error(`Only ${imageChannels} channel and no palette.`)
    process.exit(1)
  }

  imagePointContainer = new utils.PointContainer()
  imagePointContainer.setWidth(imageWidth)
  imagePointContainer.setHeight(imageHeight)
  const pointArray = imagePointContainer.getPointArray()
  for (let idx = 0, l = imagePixels.length; idx < l; ++idx) {
    const paletteIndex = imagePixels[idx]
    pointArray[idx] = utils.Point.createByQuadruplet(imagePalette[paletteIndex ?? 0] ?? [0, 0, 0, 0])
  }
}

const distanceCalculator = new distance.EuclideanBT709()
//const distanceCalculator = new distance.Manhattan()

const nearestColor = new image.NearestColor(distanceCalculator)
//const paletteQuantizer = new palette.WuQuant(distanceCalculator, colorCount)
const paletteQuantizer = new palette.RGBQuant(distanceCalculator, colorCount)
//paletteQuantizer.sample(imageQuantizer.quantizeSync(imagePointContainer, megaDrivePalette)) // Sample image as converted to mega drive palette.
paletteQuantizer.sample(nearestColor.quantizeSync(imagePointContainer.clone(), imageQPalette)) // Sample image as converted to mega drive palette.

const reducedPalette = paletteQuantizer.quantizeSync() // Final palette
console.log(reducedPalette)

//const imageQuantizer = new image.ErrorDiffusionArray(distanceCalculator, image.ErrorDiffusionArrayKernel.FloydSteinberg)
const imageQuantizer = new image.ErrorDiffusionArray(distanceCalculator, image.ErrorDiffusionArrayKernel.Atkinson, false, 2.0 / 16.0)
const reducedImage = imageQuantizer.quantizeSync(imagePointContainer.clone(), reducedPalette) // Image converted to reduced final palette

const reducedImagePath = resolve(dirname(imagePath), `${basename(imagePath, extname(imagePath))}-reduced.png`)
console.log(`Reduced palette to ${reducedPalette.getPointContainer().toUint32Array().length} colors.`)
console.log(`Writing ${reducedImagePath}...`)
await writeFile(reducedImagePath, encode({
  channels: 1,
  depth: 8, 
  width: imageWidth, 
  height: imageHeight, 
  palette: reducedPalette.getPointContainer().getPointArray().map(point => [point.r, point.g, point.b, point.a]),
  data: getIndexArray(reducedImage, reducedPalette, distanceCalculator)
}))

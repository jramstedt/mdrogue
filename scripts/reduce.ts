import { readFile, writeFile } from 'node:fs/promises'
import { basename, dirname, extname, resolve } from 'node:path'
import { decode, encode } from 'fast-png'
import { utils, palette, distance, image } from 'image-q'
import { palette as megaDrivePalette } from './megadrive.ts'
import { getIndexArray } from './utils.ts'

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

var distanceCalculator = new distance.ManhattanNommyde()
const quant = new palette.WuQuant(distanceCalculator, colorCount)

const newPalette = new utils.Palette()
newPalette.add(utils.Point.createByRGBA(0, 0, 0, 0))
for (const color of megaDrivePalette)
  newPalette.add(utils.Point.createByRGBA(...color, 255))

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

const nearestColor = new image.NearestColor(distanceCalculator)

quant.sample(nearestColor.quantizeSync(imagePointContainer, newPalette)) // Sample image as converted to mega drive palette.

const reducedPalette = quant.quantizeSync() // Final palette
const reducedImage = nearestColor.quantizeSync(imagePointContainer, reducedPalette) // Image converted to reduced final palette

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

import { readFileSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { inflateSync, gunzipSync } from 'node:zlib'
import { execa } from 'execa'

import { type Group, ID_MASK, isGroup, isTileLayer, type Layer, type TiledMap, type TileLayer } from './tiled.js'
import { writeMegaDrivePatterns } from './megadrive.js'

function getTileIndexInTileset(globalId: number): number {
  globalId = globalId & ID_MASK
  let tileId = globalId

  for(let i = 0; i < mapData.tilesets.length; ++i) {
    const firstgid = mapData.tilesets[i].firstgid
    if (firstgid > globalId) break

    tileId = globalId - firstgid
  }

  return tileId
}

const patternSize = 8 // Mega Drive uses 8x8 pixel patterns.

const [,, mapFilename, targetDirectory] = process.argv

if (mapFilename === undefined || mapFilename.length === 0) {
  console.error('Tiled map filename missing.')
  process.exit(1)
}

if (targetDirectory === undefined || targetDirectory.length === 0) {
  console.error('Target directory missing.')
  process.exit(2)
}

const mapData: TiledMap = JSON.parse(readFileSync(mapFilename, { encoding: 'utf8' }))

const chunkSize = [
  mapData.editorsettings?.chunksize?.width ?? 32,
  mapData.editorsettings?.chunksize?.height ?? 32,
] as const
const chunkVolume = chunkSize[0] * chunkSize[1]

const tileLayers = mapData.layers.filter(isTileLayer)

const minX = tileLayers.reduce((min, layer) => Math.min(min, layer.startx ?? layer.x), Infinity)
const maxX = tileLayers.reduce((max, layer) => Math.max(max, (layer.startx ?? layer.x) + layer.width), -Infinity)
const minY = tileLayers.reduce((min, layer) => Math.min(min, layer.starty ?? layer.y), Infinity)
const maxY = tileLayers.reduce((max, layer) => Math.max(max, (layer.starty ?? layer.y) + layer.height), -Infinity)

const mapPatterns = [
  maxX - minX,
  maxY - minY
] as const
const mapPatternsVolume = mapPatterns[0] * mapPatterns[1]

const chunks = [
  Math.ceil(mapPatterns[0] / chunkSize[0]),
  Math.ceil(mapPatterns[1] / chunkSize[1])
] as const

const rawType = new ArrayBuffer(mapPatternsVolume >>> 1) // nibble per pattern

const collisionType: DataView[][] = []
for (let chunkY = 0; chunkY < chunks[1]; ++chunkY) {
  const typeRow = collisionType[chunkY] ??= []
  const rowOffset = chunkY * chunks[0]

  for (let chunkX = 0; chunkX < chunks[0]; ++chunkX) {
    const dataOffset = (rowOffset + chunkX) * chunkVolume

    typeRow[chunkX] = new DataView(rawType, dataOffset >>> 1, chunkVolume >>> 1)
  }
}

const collisionLayers = mapData.layers
  .filter(isTileLayer)
  .filter(layer => {
    if (layer.properties === undefined) return false
    for(const property of layer.properties)
      if(property.name === 'collision' && property.value === true)
        return true

    return false
  })

mapData.tilesets.sort((first, second) => first.firstgid - second.firstgid)

for (const layer of collisionLayers) {
  let data: Buffer

  if (layer.encoding === 'base64') {
    if (typeof layer.data !== 'string') continue

    data = Buffer.from(layer.data, 'base64')

    if (layer.compression === 'zlib')
      data = inflateSync(data)
    else if(layer.compression === 'gzip')
      data = gunzipSync(data)
    //else if(layer.compression === 'zstd')
    //  data = zstd.decompressSync(data)
    else
      throw new Error(`compression '${layer.compression}' not supported`)
  } else if(layer.encoding === 'csv') {
    throw new Error('csv not supported.')
  } else {
    throw new Error('tile objects not supported.')
    //data = Buffer.from(layer.data)
  }

  const dataView = new Uint32Array(data.buffer)

  for (let y = 0; y < layer.height; ++y) {
    const realY = layer.y + y
    const chunkY = Math.trunc(realY / chunkSize[1])

    for (let x = 0; x < layer.width; ++x) {
      const globalTileId = dataView[y * layer.width + x]
      if (globalTileId === 0) continue  // free tile

      const realX = layer.x + x
      const chunkX = Math.trunc(realX / chunkSize[0])

      const typeChunk = collisionType[chunkY][chunkX]

      const tileIndex = getTileIndexInTileset(globalTileId)
      const tileType = (tileIndex + 1) << 4 // Zero is free tile
      // console.log(realX, realY, globalTileId)

      const patternInChunkPosition = (realY % chunkSize[1]) * chunkSize[0] + (realX % chunkSize[0])
      const typeByteOffset = patternInChunkPosition >>> 1

      const typeShift = (realX & 1) * 4
      const typeMask = 0xF0 >>> typeShift

      const currentType = typeChunk.getUint8(typeByteOffset)
      const wasSetBefore = (currentType & typeMask) !== 0

      const shiftedTileType = tileType >>> typeShift
      if (wasSetBefore && (currentType & typeMask) !== shiftedTileType)  // If one layer has already added different. Just set it to solid.
        typeChunk.setUint8(typeByteOffset, (currentType & ~typeMask) | (0x10 >>> typeShift))
      else
        typeChunk.setUint8(typeByteOffset, currentType | shiftedTileType)
    }
  }
}

function hideParams(...layers: Layer[]): string[] {
  return layers.map(layer => `--hide-layer "${layer.name}"`)
}
function showParams(...layers: Layer[]): string[] {
  return layers.map(layer => `--show-layer "${layer.name}"`)
}

function filterLayers (map: TiledMap, ...filters: string[]): Layer[] {
  const layers: Layer[] = []

  const filterLayers = (group: Group, filters: string[]): Layer[] => {
    const matchingLayers: Layer[] = [] 
    for (const layer of group.layers) {
      if (isGroup(layer)) matchingLayers.push(...filterLayers(layer, filters))
      else if (filters.every(filter => layer.name.toLocaleLowerCase().includes(filter))) matchingLayers.push(layer)
    }
    return matchingLayers
  }

  for (const layer of map.layers) {
    if (isGroup(layer)) layers.push(...filterLayers(layer, filters))
    else if (filters.every(filter => layer.name.toLocaleLowerCase().includes(filter))) layers.push(layer)
  }

  return layers
}

const paramCollisionLayers = filterLayers(mapData, 'collision')
const planeALayers = filterLayers(mapData, 'plane a')
const planeAHighLayers = filterLayers(mapData, 'plane a', 'high')

const planeBLowLayers = filterLayers(mapData, 'plane b', 'low')
const planeBHighLayers = filterLayers(mapData, 'plane b', 'high')

writeFileSync(resolve(targetDirectory, 'col.data.bin'), new DataView(rawType))

const tmxrasterizer = `${process.env['USERPROFILE']}\\Downloads\\tiled-windows-64bit-snapshot\\tmxrasterizer.exe`
const tmxrasterizeroptions = ['--no-smoothing']

execa(tmxrasterizer, [...tmxrasterizeroptions, ...showParams(...paramCollisionLayers), mapFilename, resolve(targetDirectory, 'collision.png')], { windowsVerbatimArguments: true })
  .then(async ({ stdout, stderr }) => { if (stderr.length !== 0) return console.error(new Error(stderr)) })

const planeBLowImage = resolve(targetDirectory, 'planeB-low.png')
const planeBHighImage = resolve(targetDirectory, 'planeB-high.png')
const planeBPatterns = Promise.all([
  execa(tmxrasterizer, [...tmxrasterizeroptions, ...showParams(...planeBLowLayers), mapFilename, planeBLowImage], { windowsVerbatimArguments: true }),
  // execa(tmxrasterizer, [...tmxrasterizeroptions, ...showParams(...planeBHighLayers), mapFilename, planeBHighImage], { windowsVerbatimArguments: true })
])
.then(results => { for (const { stdout, stderr } of results) if (stderr.length !== 0) return console.error(new Error(stderr)) })
.then(() => writeMegaDrivePatterns('planeB', [{ filePath: planeBLowImage, highPriority: false }, /*{ filePath: planeBHighImage, highPriority: true }*/], targetDirectory) )

const planeAImage = resolve(targetDirectory, 'planeA.png')
execa(tmxrasterizer, [...tmxrasterizeroptions, ...showParams(...planeALayers), mapFilename, planeAImage], { windowsVerbatimArguments: true })
  .then(async ({ stdout, stderr }) => { if (stderr.length !== 0) return console.error(new Error(stderr)) })
  .then(async () => writeMegaDrivePatterns('planeA', [ { filePath: planeAImage, highPriority: true } ], targetDirectory, await planeBPatterns))

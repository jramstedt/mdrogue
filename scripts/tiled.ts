
export interface Layer {
  id: number,
  name: string,
  type: 'tilelayer' | 'objectgroup' | 'imagelayer' | 'group',
  properties: { name: string, value: boolean | number | string }[],
  startx?: number,
  starty?: number,
  offsetx: number,
  offsety: number,
  x: number,
  y: number,
  tintcolor: number,
  visible: boolean
}

export interface ImageLayer extends Layer {
  type: 'imagelayer',
  transparentcolor: string,
  image: string,
  width: number,
  height: number
}
export function isImageLayer(layer: Layer): layer is ImageLayer {
  return layer.type === 'imagelayer'
}

export interface TileLayer extends Layer {
  type: 'tilelayer',
  encoding: 'csv' | 'base64',
  compression: 'zlib' | 'gzip' /*| 'zstd'*/,
  data: string | number[],
  chunks?: Layer[],
  width: number,
  height: number
}
export function isTileLayer(layer: Layer): layer is TileLayer {
  return layer.type === 'tilelayer'
}

export interface Group extends Layer {
  type: 'group',
  layers: Layer[]
}
export function isGroup(layer: Layer): layer is Group {
  return layer.type === 'group'
}

export interface ObjectGroup extends Layer {
  type: 'objectgroup',
  objects: unknown[],
  draworder: 'topdown' | 'index'
}
export function isObjectGroup(layer: Layer): layer is ObjectGroup {
  return layer.type === 'objectgroup'
}

export interface TiledMap { 
  layers: Layer[],
  editorsettings?: { chunksize?: { width: number, height:number }},
  tilesets: { firstgid: number }[]
}

export const FLIPPED_HORIZONTALLY_FLAG = 0x80000000
export const FLIPPED_VERTICALLY_FLAG   = 0x40000000
export const FLIPPED_DIAGONALLY_FLAG   = 0x20000000
export const ID_MASK = ~(FLIPPED_HORIZONTALLY_FLAG | FLIPPED_VERTICALLY_FLAG | FLIPPED_DIAGONALLY_FLAG)

import type { Canvas, CanvasRenderingContext2D } from 'canvas'

declare module 'rgbquant' {
  enum HistogramMethod {
    TopPopulation = 1,
    MinPopulation = 2
  }

  type Kernel = 'FloydSteinberg' | 'FalseFloydSteinberg' | 'Stucki' | 'Atkinson' | 'Jarvis' | 'Burkes' | 'Sierra' | 'TwoSierra' | 'SierraLite'

  type Image = HTMLImageElement| HTMLCanvasElement | Canvas | CanvasRenderingContext2D | ImageData | number[] | Uint8Array | Uint8ClampedArray | Uint32Array

  type Triplet = [r: number, g: number, b: number]

  interface SharedOptions {
    /** 1 = by global population, 2 = subregion population threshold */
    method: HistogramMethod
    /** desired final palette size */
    colors: number
    /** # of highest-frequency colors to start with for palette reduction */
    initColors: number
    /** color-distance threshold for initial reduction pass */
    initDist: number
    /** subsequent passes threshold */
    distIncr: number
    /** palette grouping */
    hueGroups: number
    /** palette grouping */
    satGroups: number
    /** palette grouping */
    lumGroups: number
    /** if > 0, enables hues stats and min-color retention per group */
    minHueCols: number
    /** subregion partitioning box size */
    boxSize: [width: number, height: number]
    /**  number of same pixels required within box for histogram inclusion */
    boxPxls: number,
    /** palette locked indicator */
    palLocked: boolean

    /** dithering/error diffusion kernel name */
    dithKern: Kernel
    /** dither serpentine pattern */
    dithSerp: boolean
    /** minimum color difference (0-1) needed to dither */
    dithDelta: number

    /** enable color caching (also incurs overhead of cache misses and cache building) */
    useCache: boolean
    /** min color occurance count needed to qualify for caching */
    cacheFreq: number
    /** allows pre-defined palettes to be re-indexed (enabling palette compacting and sorting) */
    reIndex: boolean
    /** selection of color-distance equation */
    colorDist: 'euclidean' | 'manhattan'
  }

  export interface Options extends SharedOptions {
    /** palette - rgb triplets */
    palette: Triplet[]
  }

  export class HueStats {
    numGroups: number
    minCols: number
    stats: Record<number, { num: number, cols: number[] }>
    groupsFull: number

    constructor(hueGroups: number, minHueCols: number)

    check (i32: number): void
    inject(histG: number[] | Record<number, number>)
  }

  export class RgbQuant extends SharedOptions {
    histogram: Record<number, number>
    idxrgb: Triplet[]
    idxi32: number[]
    i32idx: Record<number, number>
    i32rgb: Record<number, Triplet>
    hueStats: HueStats

    constructor(opts?: Partial<Options>)

    sample (image: Extract<Image, { width: number}>): void
    sample (image: Image, width?: number): void

    reduce (image: Image, retType?: 1, dithKern?: Kernel, dithSerp?: boolean): Uint8Array
    reduce (image: Image, retType: 2, dithKern?: Kernel, dithSerp?: boolean): number[]

    palette (tuples: tru, noSort: boolean): Triplet[]
    palette (tuples: false, noSort: boolean): Uint8Array

    private dither (image: Image, kernel: Kernel, serpentine: boolean): Uint32Array
    private buildPal (noSort: boolean): void
    private prunePal (keep: number[]): void
    private reducePal (idxi32: number[]): void
    private colorStats1D (buf32: Uint32Array): void
    private colorStats2D (buf32: Uint32Array, width: number): void
    private sortPal (): void
    private nearestColor (i32: number): number
    private nearestIndex (i32: number): number
    private cacheHistogram (idxi32: number[]): void
  }

  export default RgbQuant;
}

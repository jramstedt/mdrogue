export function concatenate (...arrays: Uint32Array[]): Uint32Array {
  const totalBytes = arrays.reduce((accumulator, currentValue) => accumulator + currentValue.byteLength, 0)
  const buffer = new ArrayBuffer(totalBytes)
  const concatenated = new Uint32Array(buffer)
  arrays.reduce((valuesWritten, array) => (concatenated.set(array, valuesWritten), valuesWritten + array.length), 0)

  return concatenated
}

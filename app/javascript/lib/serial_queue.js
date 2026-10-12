export function createSerialQueue() {
  let tail = Promise.resolve()

  return {
    enqueue(task) {
      const run = tail.then(() => task())
      tail = run.catch(() => {})
      return run
    }
  }
}

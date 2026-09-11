# Can we consider webcontainers a viable alternative for traditional containerization?

The basis of this is to conclude on wether running Ai agents in the web via webcontainers is a viable solution compared to traditional containers on a server.

Since the program is run locally computer and the computing power is done on the users machine, the performance of the Ai agent is dependent on the users system components (CPU, RAM), and the size of the environment the virtual machine is run in. Since all modern browsers support WebAssembly, running the webcontainer in the browser is of no issue. A check on wether a browser supports WebAssembly can be run by `typeof WebAssembly === "object"` in the browsers console. A return of `True` or `Object` means the browser supports it.

LLM used in the container: https://huggingface.co/dphn/Dolphin3.0-Llama3.2-1B chosen for its low parameter count and small memory footprint.

See repo for Dockerfile.



## Benchmarking
To get an Idea of how much CPU and RAM usage the WASI webcontainer uses, a benchmark of the VM using [Dolphin 3.0 Llama 3.2 1B](https://huggingface.co/dphn/Dolphin3.0-Llama3.2-1B) LLM was conducted.

Host OS:
- Win 10
- 96GB DDR4 RAM
- AMD Ryzen 7 5800x 8-cores, 3.80GHz Base speed
- Tested in firefox and Chrome





# OPTION A: WASI on browser

This path uses Bochs, a cross-platform x86 emulator, compiled to WASI. It runs as a single-threaded interpreter with no JIT — every instruction is decoded and executed in software. It can be built with or without networking support.

Guest RAM is set via `VM_MEMORY_SIZE_MB` (default 128MB). At the default, the VM crashes once the container needs more memory than that to load the LLM. Raising it to 2048MB causes a build-time compilation error; halving that to 1024MB builds and runs successfully. This suggests a real, undocumented ceiling somewhere between those two values for this specific Bochs fork.



## How it works

```
Docker container
     ↓
compile/package for Wasm
     ↓
.wasm
     ↓
website downloads .wasm
     ↓
WebAssembly runtime
     ↓
program executes inside browser sandbox
```


## Benchmark Results

| Browser | Loading Linux environment | Loading LLM | Browser RAM Usage on Boot |
|---------|---------------------------|-------------|---------------------------|
| Firefox | ~13 seconds               | ~8:17       |      3-4GB                |
| Chrome  | ~9 seconds                | ~7:30       |      ~4.2GB               |

<hr>
<br>
<br>
<br>
<br>





# OPTION B: Emscripten on browser

This path compiles the container using Emscripten (emcc), which cross-compiles QEMU (x86_64 target) into JS + WebAssembly. Unlike Bochs, QEMU's TCG backend provides real JIT compilation, and this build supports multi-threading via `SharedArrayBuffer`. Like Option A, it can be built with or without networking.


## How it works

```
Docker container
     ↓
compile/package with Emscripten (emcc)
     ↓
QEMU (x86_64 target) cross-compiled to Wasm + JS glue
     ↓
out.js (JS loader/glue)  +  qemu-system-x86_64.wasm  +  qemu-system-x86_64.data (embedded rootfs/kernel)
     ↓
website loads out.js, which fetches and instantiates the .wasm + .data
     ↓
Emscripten runtime sets up a Web Worker (PROXY_TO_PTHREAD) + SharedArrayBuffer
     ↓
WebAssembly runtime executes QEMU's TCG JIT inside that worker thread
     ↓
QEMU emulates a full x86_64 machine (CPU, RAM, virtio devices) and boots a real Linux kernel inside it
     ↓
your container's init process runs inside that emulated Linux, piped to xterm via a virtual TTY
```

Unlike Bochs, this build's WASM memory is capped by a fixed, non-growable TOTAL_MEMORY set at compile time (~3000MB for the x86_64 target), shared between QEMU's own JIT/runtime overhead and the guest VM's configured RAM `VM_MEMORY_SIZE_MB`. Requesting guest RAM too close to that ceiling leaves too little headroom for QEMU itself and can cause a silent startup failure with no console error.


## Benchmark Results

| Browser | Loading Linux environment | Loading LLM | Browser RAM Usage on Boot |
|---------|---------------------------|-------------|---------------------------|
| Firefox | unknown                   | unknown     |      unknown              |
| Chrome  | unknown                   | unknown     |      unknown              |



# Things to note
- `VM_MEMORY_SIZE_MB=` is the only flag to increase environment memory size. Too high causes possible crash, too low causes system to malfunction and crash (wants more memory).
- `VM_CORE_NUMS=` changes the number of cores that gets emulated with MTTCG(Multi-threaded TCG) enabled. Only works with `--to-js` flag (emscripten), not `WASI`.



# Conclusion

Are web containers a viable solution to run Ai agents locally in the web?

Option A: Due to the hard limit of 1024MB (1GB) of VM MEMORY without any crashes and how long it takes for the LLM in the example to load the environment and produce an answer, it is not a viable solution.

Option B: In theory since the container is compiled using emscripten leveraging QEMU JIT and supporting multi threading, option B would be a much suitable solution, but without being able to test completely, the answer isn't definite on wether running an Ai agent in a webcontainer is a vaible solution.




<br>
<br>
<br>

# Reference

- https://github.com/container2wasm/container2wasm 

###### OPTION A
- https://github.com/container2wasm/container2wasm/tree/main/examples/wasi-browser

###### OPTION B
- https://github.com/container2wasm/container2wasm/tree/main/examples/emscripten-simple
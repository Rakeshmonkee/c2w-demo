FROM ubuntu:22.04 AS build
RUN apt-get update && apt-get install -y build-essential cmake git
RUN git clone https://github.com/ggml-org/llama.cpp /work
WORKDIR /work
RUN cmake -B build \
    -DGGML_NATIVE=OFF -DGGML_AVX=OFF -DGGML_AVX2=OFF \
    -DGGML_FMA=OFF -DGGML_F16C=OFF -DGGML_AVX512=OFF \
    -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build --config Release -j$(nproc)

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y libgomp1 ca-certificates curl && rm -rf /var/lib/apt/lists/*
COPY --from=build /work/build/bin/ /usr/local/bin/
ENV LD_LIBRARY_PATH=/usr/local/bin
RUN curl -L -o /model.gguf \
    https://huggingface.co/bartowski/Dolphin3.0-Llama3.2-1B-GGUF/resolve/main/Dolphin3.0-Llama3.2-1B-Q4_K_M.gguf
ENTRYPOINT ["/usr/local/bin/llama-cli", "-m", "/model.gguf", "-t", "1"]
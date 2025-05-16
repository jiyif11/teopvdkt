### 修改.bashrc<br>

`````
export PATH=/usr/local/cuda/bin:$PATH 
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
`````

### 安装cuda 12.6<br>

### 安装依赖<br>

`````
apt update
apt install -y build-essential ninja-build patchelf libstdc++6 cmake numactl
apt install libtbb-dev libssl-dev libcurl4-openssl-dev libaio1t64 libaio-dev libgflags-dev zlib1g-dev libfmt-dev
`````

### 下载源码<br>

<<<<<<< HEAD
`````
git clone http://192.168.4.222/lql/arm-kt.git
cd arm-kt
git submodule update --init --recursive
pip install torch -i https://download.pytorch.org/whl/cu126
pip install *.whl
bash install.sh
`````
=======
* **May 14, 2025**: Support Intel Arc GPU ([Tutorial](./doc/en/xpu.md)).

* **Apr 29, 2025**: Support AMX-Int8、 AMX-BF16 and Qwen3MoE ([Tutorial](./doc/en/AMX.md))

https://github.com/user-attachments/assets/fafe8aec-4e22-49a8-8553-59fb5c6b00a2
>>>>>>> a3346c9a41535cfa38a62ba9e4a2fa200d78278a


### 启动命令<br>

`````
numactl --physcpubind=0-31,64-96 ktransformers --optimize_config_path /root/arm-kt/ktransformers/optimize/optimize_rules/DeepSeek-V3-Chat-serve.yaml --model_path /root/deepseek-R1 --gguf_path /root/deepseek-R1/DeepSeek-R1-Q4_K_M --cpu_infer 60 --max_new_tokens 1024 --no-force_think --max_batch_size 4 --host 0.0.0.0 --port 10002 --cache_lens 32768 --backend_type balance_serve --cache_q4 true --use_cuda_graph
`````

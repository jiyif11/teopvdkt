### 修改.bashrc<br>

`````
export PATH=/usr/local/cuda/bin:$PATH 
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cudaexport LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libtcmalloc_minimal.so.4
`````


### 安装cuda 12.6<br>

### 安装依赖<br>

`````
apt update
apt install -y libtcmalloc-minimal4 numactl
`````

### 下载源码<br>

`````
git clone http://192.168.4.222/lql/arm-kt.git
cd arm-kt
pip install torch torchvision torchaudio -i https://download.pytorch.org/whl/cu126
pip install -r requirements-local_chat.txt
pip install -r ktransformers/server/requirements.txt
pip install third_party/custom_flashinfer/
pip install *.whl
`````


### 启动命令<br>

`````
numactl --physcpubind=0-31,64-96 python -m ktransformers.server.main --optimize_config_path /root/arm-kt/ktransformers/optimize/optimize_rules/DeepSeek-V3-Chat-serve.yaml --model_path /root/deepseek-R1 --gguf_path /root/deepseek-R1/DeepSeek-R1-Q4_K_M --cpu_infer 60 --max_new_tokens 1024 --force_think --max_batch_size 4 --host 0.0.0.0 --port 10002 --cache_lens 32768 --backend_type balance_serve
`````

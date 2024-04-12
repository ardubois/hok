git pull
nvcc --shared -g --compiler-options '-fPIC' -o mudule.so module.cu
nvcc --shared -g --compiler-options '-fPIC' teste_module.cu


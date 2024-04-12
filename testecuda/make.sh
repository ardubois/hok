git pull
nvcc --shared -g --compiler-options '-fPIC' -o module.so module.cu
nvcc teste_module.cu


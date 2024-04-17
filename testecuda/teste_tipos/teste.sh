git pull
nvcc --shared -g --compiler-options '-fPIC' -o module2.so module2.cu
nvcc teste_module2.cu


git pull
nvcc --shared -g --compiler-options '-fPIC' -o mudule.so module.cu
nvcc teste_module.cu


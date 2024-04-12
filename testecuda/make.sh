git pull
nvcc --shared --compiler-options '-fPIC' -o mudule.so module.cu
nvcc teste_module.cu
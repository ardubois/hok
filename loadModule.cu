#include<stdio.h>


#include <cuda.h>
#include <builtin_types.h>
#include <cuda_runtime.h>

__global__
void inc2(float v)
{
 int x = v;
}


__device__
float inc(float v)
{
 return v+2;
}

__global__
void inc_vet(float *result, float *a, int n)
{
	// void **fun_res;

	float (*fun)(float) = inc; 
	int i= (threadIdx.x + (blockIdx.x * blockDim.x));
	if(i < n)   
            result[i] = fun(a[i]);
}




int main (int argc, char *argv[]) {
	float *a, *resp, *dev_a, *dev_resp;

	int n = 10000;

	int block_size = 32;
	int nBlocks = (n + block_size - 1) / block_size;

	printf("block_size = %d   nBlocks = %d total = %d\n", block_size,nBlocks,block_size*nBlocks);

	a = (float*)malloc(n*sizeof(float));

	
	resp = (float*)malloc(n*sizeof(float));

	for(int i=0; i<n; i++) {
		a[i] = i;
		
	}
    
	cudaMalloc((void**)&dev_a, n*sizeof(float));
	cudaMalloc((void**)&dev_resp, n*sizeof(float));
	
    cudaMemcpy(dev_a, a, n*sizeof(float), cudaMemcpyHostToDevice);


	CUmodule cuModule;

    int ret = cuModuleLoad(&cuModule, "/home/dubois/hok/loadModule.ptx");

	printf("retorno %d\n", ret);

	CUfunction function;
    int funs = 0;
//	ret = cuModuleGetFunctionCount(&funs,cuModule) ;

	printf("retorno %d funs= %d\n", ret,funs);


	ret = cuModuleGetFunction(&function, cuModule, "inc2");

	printf("retorno %d\n", ret);



	inc_vet<<<nBlocks, block_size>>>(dev_resp, dev_a , n);

	cudaMemcpy(resp,dev_resp, n*sizeof(float), cudaMemcpyDeviceToHost);

	for(int i=0; i<10; i++) {
		printf("resp[%i] = %f\n", i,resp[i]);
	}
   
	cudaFree(dev_a);
	cudaFree(dev_resp);
    
	
	free(a);
	free(resp);
  	
}
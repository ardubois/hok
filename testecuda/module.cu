#include <stdint.h>
#include <stdio.h>
#include <dlfcn.h>

__device__
float inc(float v)
{
 return v+2;
}

typedef float (*func)(float);

__device__ func ptr_inc_fun = inc;


extern "C" func ptr_inc()
{

    func pfun = NULL;
    cudaMemcpy((void*)pfun,(void*)inc, sizeof(float(*)(float)), cudaMemcpyDeviceToHost);
    return pfun;
}


__global__
void inc_vet(float *result, float *a, int n, float (*fun)(float))
{
	// void **fun_res;
    printf("fun %p\n",fun);
	printf("inc %p\n",inc);
	fun = ptr_inc_fun;
	int i= (threadIdx.x + (blockIdx.x * blockDim.x));
	if(i < n)   
            result[i] = fun(a[i]);
}

__global__
void copy_ptr(func f)
{
	 f = ptr_inc_fun;
	 printf("kernel f %p\n", f);
}

extern "C" void launch()
{
    printf("hello world\n");
    float *a, *resp, *dev_a, *dev_resp;


	int n = 10000;

	int block_size = 32;
	int nBlocks = (n + block_size - 1) / block_size;

	a = (float*)malloc(n*sizeof(float));
	resp = (float*)malloc(n*sizeof(float));

	for(int i=0; i<n; i++) {
		a[i] = i;
	}
    

	func dev_inc_pointer;
	func host_inc_pointer;

    printf("before cuda malloc\n");
	cudaMalloc((void**) &dev_inc_pointer, sizeof(func));
     printf("after cuda malloc\n");
	copy_ptr<<<1,1>>>(dev_inc_pointer);
   printf("afterkernel launch %p\n", host_inc_pointer);
	cudaMemcpyFromSymbol((void*) host_inc_pointer, (void*) dev_inc_pointer, sizeof(func), cudaMemcpyDeviceToHost);
    printf("after memory  copy %p\n",host_inc_pointer);
//	printf("pointer copied %p\n", host_inc_pointer);


	cudaMalloc((void**)&dev_a, n*sizeof(float));
	cudaMalloc((void**)&dev_resp, n*sizeof(float));
	
    cudaMemcpy(dev_a, a, n*sizeof(float), cudaMemcpyHostToDevice);

   float(*fptr)(float) =  NULL;

    cudaMemcpy((void*)fptr,(void*) inc, sizeof(float(*)(float)), cudaMemcpyDeviceToHost);
     printf("cuda mem depois \n %f", fptr);
   // inc_vet<<<nBlocks, block_size>>>(dev_resp, dev_a , n,ptr_inc_fun);
inc_vet<<<2, 2>>>(dev_resp, dev_a , n,fptr);
    cudaError_t error_gpu = cudaGetLastError();
    if(error_gpu != cudaSuccess)
     { char message[200];
       strcpy(message,"Error kernel call: ");
       strcat(message, cudaGetErrorString(error_gpu));
       printf(message);
     }

	cudaMemcpy(resp,dev_resp, n*sizeof(float), cudaMemcpyDeviceToHost);

	for(int i=0; i<10; i++) {
		printf("resp[%i] = %f\n", i,resp[i]);
	}
   
	cudaFree(dev_a);
	cudaFree(dev_resp);
    
	
	free(a);
	free(resp);


}
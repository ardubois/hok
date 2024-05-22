#include <stdio.h>
#include <time.h>

__device__
float saxpy(float a, float b)
{
return (((2 * a) + b));
}

__device__ void* saxpy_ptr = (void*) saxpy;

extern "C" void* get_saxpy_ptr()
{
        void* host_function_ptr;
        cudaMemcpyFromSymbol(&host_function_ptr, saxpy_ptr, sizeof(void*));
        return host_function_ptr;
}

__global__
void map_2kernel(float *a1, float *a2, float *a3, int size, float (*f)(float,float))
{
int id = ((blockIdx.x * blockDim.x) + threadIdx.x);
if((id < size))
{
        a3[id] = f(a1[id], a2[id]);
}

}

int main(int argc, char *argv[])
{

    float *a, *b, *resp;
	float *dev_a, *dev_b, *dev_resp;

    int N = atoi(argv[1]);

    a = (float*)malloc(N*sizeof(float));
    b = (float*)malloc(N*sizeof(float));
    resp = (float*)malloc(N*sizeof(float));

    for(int i=0; i<N; i++) {
		a[i] = i+1;
		
	}

    for(int i=0; i<N; i++) {
		b[i] = i+1;
		
	}


    int threadsPerBlock = 128;
    int  numberOfBlocks = (N + threadsPerBlock - 1)/ threadsPerBlock;

   

    float time;
    cudaEvent_t start, stop;   
    cudaEventCreate(&start) ;
    cudaEventCreate(&stop) ;
    cudaEventRecord(start, 0) ;


	cudaMalloc((void**)&dev_a, N*sizeof(float));
	cudaMalloc((void**)&dev_b, N*sizeof(float));
	cudaMalloc((void**)&dev_resp, N*sizeof(float));
	cudaMemcpy(dev_a, a, N*sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(dev_b, b, N*sizeof(float), cudaMemcpyHostToDevice);

    float (*f)(float,float) = (float (*)(float,float)) get_saxpy_ptr();

    map_2kernel<<< numberOfBlocks, threadsPerBlock>>>(dev_a, dev_b, dev_resp, N, f);

    cudaMemcpy(resp, dev_resp, N*sizeof(float), cudaMemcpyDeviceToHost);

    for(int i=0; i<10; i++) {
		printf("resp[%d] = %f;\n",i,resp[i]);
	}

    cudaFree(dev_a);
	cudaFree(dev_b);
    cudaFree(dev_resp);
    
	cudaEventRecord(stop, 0) ;
    cudaEventSynchronize(stop) ;
    cudaEventElapsedTime(&time, start, stop) ;

    printf("CUDA\t%d\t%3.1f\n", N,time);

	//printf("\n FINAL RESULTADO: %f \n", c);

	free(a);
    free(b);
	free(resp);

}

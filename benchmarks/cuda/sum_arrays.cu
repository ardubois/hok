#include <stdio.h>
#include <time.h>

__global__
void map2_xy_kernel(float *a1, float *a2, float *r, int size, float (*f)(float*,float*,int))
{
int id = ((blockIdx.x * blockDim.x) + threadIdx.x);
if((id < size))
{
        r[id] = f(a1, a2, id);
}

}

__device__
float anonymous(float *a1, float *a2, int i)
{
return ((a1[i] + a2[i]));
}

__device__ void* anonymous_ptr = (void*) anonymous;

extern "C" void* get_anonymous_ptr()
{
        void* host_function_ptr;
        cudaMemcpyFromSymbol(&host_function_ptr, anonymous_ptr, sizeof(void*));
        return host_function_ptr;
}





int main(int argc, char *argv[])
{

    float *a, *b, *resp;
	float *dev_a, *dev_b, *dev_resp;
    cudaError_t j_error;

    int N = atoi(argv[1]);

    a = (float*)malloc(N*sizeof(float));
    b = (float*)malloc(N*sizeof(float));
    resp = (float*)malloc(N*sizeof(float));

    for(int i=0; i<N; i++) {
		a[i] = 1;
		
	}

    for(int i=0; i<N; i++) {
		b[i] = 2;
		
	}


    int threadsPerBlock = 128;
    int  numberOfBlocks = (N + threadsPerBlock - 1)/ threadsPerBlock;

    float time;
    cudaEvent_t start, stop;   
    cudaEventCreate(&start) ;
    cudaEventCreate(&stop) ;
    cudaEventRecord(start, 0) ;


	cudaMalloc((void**)&dev_a, N*sizeof(float));
    j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}
	cudaMalloc((void**)&dev_b, N*sizeof(float));
    j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}
	cudaMalloc((void**)&dev_resp, N*sizeof(float));
    j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}
	cudaMemcpy(dev_a, a, N*sizeof(float), cudaMemcpyHostToDevice);
     j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}
    cudaMemcpy(dev_b, b, N*sizeof(float), cudaMemcpyHostToDevice);
     j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}

    float (*f)(float*,float*,int) = (float (*)(float*,float*,int)) get_anonymous_ptr();

   map2_xy_kernel<<< numberOfBlocks, threadsPerBlock>>>(dev_a, dev_b, dev_resp, N, f);
    
     j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}

    cudaMemcpy(resp, dev_resp, N*sizeof(float), cudaMemcpyDeviceToHost);
     j_error = cudaGetLastError();
    if(j_error != cudaSuccess) {printf("Error: %s\n", cudaGetErrorString(j_error)); exit(1);}

    
    cudaFree(dev_a);
	cudaFree(dev_b);
    cudaFree(dev_resp);
    
	cudaEventRecord(stop, 0) ;
    cudaEventSynchronize(stop) ;
    cudaEventElapsedTime(&time, start, stop) ;

    printf("CUDA\t%d\t%3.1f\n", N,time);

/*
    for(int i=0; i<10; i++) {
		printf("resp[%d] = %f;\n",i,resp[i]);
	}
*/

	//printf("\n FINAL RESULTADO: %f \n", c);

	free(a);
    free(b);
	free(resp);

}

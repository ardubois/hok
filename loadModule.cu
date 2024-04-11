__global__
void inc(float v)
{
 return v+1;
}

__global__
void inc_vet(float *result, float *a, int n)
{
	int i= (threadIdx.x + (blockIdx.x * blockDim.x));
	if(i < n)   
            result[i] = inc(a[i]);
}




int main (int argc, char *argv[]) {
	float *a, *resp, *dev_a, *dev_resp;

	int n = 10000;

	a = (float*)malloc(n*sizeof(float));

	
	resp = (float*)malloc(n*sizeof(float));

	for(int i=0; i<n; i++) {
		a[i] = i;
		
	}
    
	cudaMalloc((void**)&dev_a, n*sizeof(float));
	cudaMalloc((void**)&dev_resp, n*sizeof(float));
	
    cudaMemcpy(dev_a, a, N*sizeof(float), cudaMemcpyHostToDevice);
	
	inc_vet<<<blocksPerGrid, threadsPerBlock>>>(dev_result, dev_a , n);

	cudaMemcpy(resp,dev_resp, n*sizeof(float), cudaMemcpyDeviceToHost);

	c = 0;
	for(int i=0; i<10; i++) {
		printf("resp[%i] = %f", i,resp[i]);
	}
   
	cudaFree(dev_a);
	cudaFree(dev_resp;
    
	
	free(a);
	free(resp);
  	
}
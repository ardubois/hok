
__device__
float anonymous_o39d60fgbe(float x, float y)
{
float x;
float y;
	float n = (x + y);
return(n);
}

__device__ void* anonymous_o39d60fgbe_ptr = (void*) anonymous_o39d60fgbe;

extern "C" void* get_anonymous_o39d60fgbe_ptr()
{
	void* host_function_ptr;
	cudaMemcpyFromSymbol(&host_function_ptr, anonymous_o39d60fgbe_ptr, sizeof(void*));
	return host_function_ptr;
}



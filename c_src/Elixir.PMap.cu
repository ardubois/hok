#include "erl_nif.h"


__device__
float sum(float a, float b)
{
return((a + b));
}

__device__ void* sum_ptr = (void*) sum;

extern "C" void* get_sum_ptr()
{
	void* host_function_ptr;
	cudaMemcpyFromSymbol(&host_function_ptr, sum_ptr, sizeof(void*));
	return host_function_ptr;
}



__global__
void map2(float *a1, float *a2, float *a3, int size, float (*f)(float,float))
{
int id = ((blockIdx.x * blockDim.x) + threadIdx.x);
if((id < size))
{
	a3[id] = (*f)(a1[id], a2[id]);
}

}

extern "C" void map2_call(ErlNifEnv *env, const ERL_NIF_TERM argv[], ErlNifResourceType* type,ErlNifResourceType* ftype)
  {

    ERL_NIF_TERM list;
    ERL_NIF_TERM head;
    ERL_NIF_TERM tail;
    float **array_res;
    void **fun_res;

    const ERL_NIF_TERM *tuple_blocks;
    const ERL_NIF_TERM *tuple_threads;
    int arity;

    if (!enif_get_tuple(env, argv[1], &arity, &tuple_blocks)) {
      printf ("spawn: blocks argument is not a tuple");
    }

    if (!enif_get_tuple(env, argv[2], &arity, &tuple_threads)) {
      printf ("spawn:threads argument is not a tuple");
    }
    int b1,b2,b3,t1,t2,t3;

    enif_get_int(env,tuple_blocks[0],&b1);
    enif_get_int(env,tuple_blocks[1],&b2);
    enif_get_int(env,tuple_blocks[2],&b3);
    enif_get_int(env,tuple_threads[0],&t1);
    enif_get_int(env,tuple_threads[1],&t2);
    enif_get_int(env,tuple_threads[2],&t3);

    dim3 blocks(b1,b2,b3);
    dim3 threads(t1,t2,t3);

    list= argv[3];

  enif_get_list_cell(env,list,&head,&tail);
  float *arg1 = *array_res;
  list = tail;

  enif_get_list_cell(env,list,&head,&tail);
  float *arg2 = *array_res;
  list = tail;

  enif_get_list_cell(env,list,&head,&tail);
  float *arg3 = *array_res;
  list = tail;

  enif_get_list_cell(env,list,&head,&tail);
  int arg4;
  enif_get_int(env, head, &arg4);
  list = tail;

  enif_get_list_cell(env,list,&head,&tail);
      float (*arg5)(float,float) = (float (*)(float,float))*fun_res;
      list = tail;

       map2<<<blocks, threads>>>(arg1,arg2,arg3,arg4,arg5);
    cudaError_t error_gpu = cudaGetLastError();
    if(error_gpu != cudaSuccess)
     { char message[200];
       strcpy(message,"Error kernel call: ");
       strcat(message, cudaGetErrorString(error_gpu));
       enif_raise_exception(env,enif_make_string(env, message, ERL_NIF_LATIN1));
     }
}

__device__
float anonymous_dm1n5andmc(float x, float y)
{


	float n = (x + y);
return(n);
}

__device__ void* anonymous_dm1n5andmc_ptr = (void*) anonymous_dm1n5andmc;

extern "C" void* get_anonymous_dm1n5andmc_ptr()
{
	void* host_function_ptr;
	cudaMemcpyFromSymbol(&host_function_ptr, anonymous_dm1n5andmc_ptr, sizeof(void*));
	return host_function_ptr;
}



__device__
float anonymous_gg5n77jemg(float x, float y)
{


	float n = (x + y);
return(n);
}

__device__ void* anonymous_gg5n77jemg_ptr = (void*) anonymous_gg5n77jemg;

extern "C" void* get_anonymous_gg5n77jemg_ptr()
{
	void* host_function_ptr;
	cudaMemcpyFromSymbol(&host_function_ptr, anonymous_gg5n77jemg_ptr, sizeof(void*));
	return host_function_ptr;
}



__device__
float anonymous_hna3kgf5ng(float x, float y)
{


	float n = (x + y);
return(n);
}

__device__ void* anonymous_hna3kgf5ng_ptr = (void*) anonymous_hna3kgf5ng;

extern "C" void* get_anonymous_hna3kgf5ng_ptr()
{
	void* host_function_ptr;
	cudaMemcpyFromSymbol(&host_function_ptr, anonymous_hna3kgf5ng_ptr, sizeof(void*));
	return host_function_ptr;
}



__device__
float anonymous_6c7bn66210(float x, float y)
{


	float n = (x + y);
return(n);
}

__device__ void* anonymous_6c7bn66210_ptr = (void*) anonymous_6c7bn66210;

extern "C" void* get_anonymous_6c7bn66210_ptr()
{
	void* host_function_ptr;
	cudaMemcpyFromSymbol(&host_function_ptr, anonymous_6c7bn66210_ptr, sizeof(void*));
	return host_function_ptr;
}



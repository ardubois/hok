#include "erl_nif.h"


__device__
float saxpy(float a, float b)
{
return(((2 * a) + b));
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
	a3[id] = (*f)(a1[id], a2[id]);
}

}

extern "C" void map_2kernel_call(ErlNifEnv *env, const ERL_NIF_TERM argv[], ErlNifResourceType* type,ErlNifResourceType* ftype)
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
    enif_get_resource(env, head, type, (void **) &array_res);
    float *arg1 = *array_res;
    list = tail;

    enif_get_list_cell(env,list,&head,&tail);
    enif_get_resource(env, head, type, (void **) &array_res);
    float *arg2 = *array_res;
    list = tail;

    enif_get_list_cell(env,list,&head,&tail);
    enif_get_resource(env, head, type, (void **) &array_res);
    float *arg3 = *array_res;
    list = tail;

    enif_get_list_cell(env,list,&head,&tail);
  int arg4;
  enif_get_int(env, head, &arg4);
  list = tail;

  enif_get_list_cell(env,list,&head,&tail);
    enif_get_resource(env, head, ftype, (void **) &fun_res);
      float (*arg5)(float,float) = (float (*)(float,float))*fun_res;
      list = tail;

       map_2kernel<<<blocks, threads>>>(arg1,arg2,arg3,arg4,arg5);
    cudaError_t error_gpu = cudaGetLastError();
    if(error_gpu != cudaSuccess)
     { char message[200];
       strcpy(message,"Error kernel call: ");
       strcat(message, cudaGetErrorString(error_gpu));
       enif_raise_exception(env,enif_make_string(env, message, ERL_NIF_LATIN1));
     }
}

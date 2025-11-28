require Hok

Hok.defmodule_rts NBodies do

  defd gpu_nBodies(p,c,n) do
    softening = 0.000000001
    dt = 0.01
    fx = 0.0
    fy = 0.0
    fz = 0.0
    for j in range(0,n) do
        dx = c[6*j] - p[0];
        dy = c[6*j+1] - p[1];
        dz = c[6*j+2] - p[2];
        distSqr = dx*dx + dy*dy + dz*dz + softening;
        invDist = 1.0/sqrt(distSqr);
        invDist3  = invDist * invDist * invDist;

        fx = fx + dx * invDist3;
        fy = fy + dy * invDist3;
        fz = fz + dz * invDist3;
      end
  p[3] = p[3]+ dt*fx;
  p[4] = p[4]+ dt*fy;
  p[5] = p[5]+ dt*fz;
  return :unit
  end
  defd gpu_integrate(p, dt, n) do
      type n int
      p[0] = p[0] + p[3]*dt;
      p[1] = p[1] + p[4]*dt;
      p[2] = p[2] + p[5]*dt;
      return :unit
  end
  deft map_step_2_para_no_resp_kernel (arr a) ~> integer ~> b ~> c ~> integer ~> [(arr a)~> b ~> c ~> unit]
  defk map_step_2_para_no_resp_kernel(d_array,  step, par1, par2,size,f) do


    globalId  = blockDim.x * ( gridDim.x * blockIdx.y + blockIdx.x ) + threadIdx.x
    id  = step * globalId
    #f(id,id)
    if (globalId < size) do
      f(d_array+id,par1,par2)
    end
  end
  def map_2_para_no_resp(d_array,  par1, par2, size, f) do
    block_size =  128;
    {_l,step} = Hok.get_shape_gnx(d_array)
    nBlocks = floor ((size + block_size - 1) / block_size)

      Hok.spawn_rts(&NBodies.map_step_2_para_no_resp_kernel/6,{nBlocks,1,1},{block_size,1,1},[d_array,step,par1,par2,size,f])
      d_array
  end
  def nbodies(-1,p,_dt,_softening,_n) do
    p
  end
  def nbodies(i,p,dt,softening,n) do
    #p=nbodies(i-1,p,dt,softening,n)
    {fx,fy,fz} = calc_nbodies(n,i,p,softening,0.0,0.0,0.0)

    p=Matrex.set(p,1,6*i+4,Matrex.at(p,1,6*i+4)+ dt*fx);
    p=Matrex.set(p,1,6*i+5,Matrex.at(p,1,6*i+5) + dt*fy);
    p=Matrex.set(p,1,6*i+6,Matrex.at(p,1,6*i+6) + dt*fz);
    nbodies(i-1,p,dt,softening,n)
  end

def calc_nbodies(-1,_i,_p,_softening,fx,fy,fz) do
  {fx,fy,fz}
end
def calc_nbodies(j,i,p,softening,fx,fy,fz) do
    dx = Matrex.at(p,1,(6*j)+1) - Matrex.at(p,1,(6*i)+1);
    dy = Matrex.at(p,1,(6*j)+2) - Matrex.at(p,1,(6*i)+2);
    dz = Matrex.at(p,1,(6*j)+3) - Matrex.at(p,1,(6*i)+3);
    distSqr = dx*dx + dy*dy + dz*dz + softening;
    invDist = 1/:math.sqrt(distSqr);
    invDist3 = invDist * invDist * invDist;

    fx = fx + dx * invDist3;
    fy = fy + dy * invDist3;
    fz = fz + dz * invDist3;
    calc_nbodies(j-1,i,p,softening,fx,fy,fz)
end

def cpu_integrate(-1,p,_dt) do
  p
end
def cpu_integrate(i,p, dt) do
      p=Matrex.set(p,1,6*i+1,Matrex.at(p,1,6*i+1) + Matrex.at(p,1,6*i+4)*dt)
      p=Matrex.set(p,1,6*i+2,Matrex.at(p,1,6*i+2) + Matrex.at(p,1,6*i+5)*dt)
      p=Matrex.set(p,1,6*i+3,Matrex.at(p,1,6*i+3) + Matrex.at(p,1,6*i+6)*dt)
      cpu_integrate(i-1,p,dt)
end
def equality(a, b) do
  if(abs(a-b) < 0.01) do
    true
  else
    false
  end
end
def check_equality(0,_cpu,_gpu) do
  :ok
end
def check_equality(n,cpu,gpu) do
  gpu1 =Matrex.at(gpu,1,n)
  cpu1 = Matrex.at(cpu,1,n)
  if(equality(gpu1,cpu1)) do
    check_equality(n-1,cpu,gpu)
  else
    IO.puts "#{n}: cpu = #{cpu1}, gpu = #{gpu1}"
    check_equality(n-1,cpu,gpu)
  end
end
end


[arg] = System.argv()

Hok.include_rts [NBodies]


user_value = String.to_integer(arg)



nBodies = user_value #3000;
#block_size =  128;
#nBlocks = floor ((nBodies + block_size - 1) / block_size)
#softening = 0.000000001
#dt = 0.01; # time step
size_body = 6



h_buf = Hok.new_nx_from_function(nBodies,size_body,{:f,64},fn -> :rand.uniform() end )

#h_buf = PolyHok.new_nx_from_function(nBodies,size_body,{:f,32},fn -> 1 end )

#IO.inspect h_buf

prev = System.monotonic_time()

d_buf = Hok.new_gnx(h_buf)


Hok.set_default_type(%{default:  :double, a: :double, b: :tdouble, c: :int })

r1 = NBodies.map_2_para_no_resp(d_buf,d_buf,nBodies,nBodies, &NBodies.gpu_nBodies/3)

Hok.set_default_type(%{default: :double, a: :double, b: :double, c: :int })

r2 = NBodies.map_2_para_no_resp( r1, 0.01,nBodies,nBodies, &NBodies.gpu_integrate/3)
  |> Hok.get_gnx
  #|> IO.inspect

  next = System.monotonic_time()

IO.puts "Hok\t#{user_value}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"

#IO.inspect gpu_resp

#prev = System.monotonic_time()
#cpu_resp = NBodies.nbodies(nBodies-1,h_buf,dt,softening,nBodies-1)
#cpu_resp = NBodies.cpu_integrate(nBodies-1,cpu_resp,dt)
#next = System.monotonic_time()
#IO.puts "Elixir\t#{user_value}\t#{System.convert_time_unit(next-prev,:native,:millisecond)}"

#IO.inspect cpu_resp

#NBodies.check_equality(nBodies,cpu_resp,gpu_resp)

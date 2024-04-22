require Hok
x = Hok.hok fn (x,y) ->
          type x float
          type y float
          n = x+y
          return n end

Hok.CudaBackend.gen_lambda_ref("PMap",[x])

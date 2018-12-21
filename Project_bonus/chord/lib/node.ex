defmodule Nodes do
  @moduledoc """
Node module starts genserver. Then, it stores each node's pid in registry, sets up their initial state. Then it starts
requesting keys, one key per second. Every time probability is checked if the node could die. In that case there are two
types of node failure implemented - temporary and permanent. In temporary failure node tells his predecessor and
successor that he is leaving and his keys are given to successor. Then after few random number of seconds node rejoins
and contacts his predecessor and successor and keys are distributed between successor and the node again.
In permanent failure, node returns zero value and exits from program. In this case all nodes, remove that from their finger
table.

  """

  def start_link do
      {:ok,pid} = GenServer.start_link(__MODULE__,:ok, [])
      pid
  end

  @doc """
  This function initiates the requesting procedure by first getting max node from finger table which is less then equals key.
  """
  def begin(pid,numN) do

    #IO.puts("Hey there !")
    #IO.inspect pid
    w=get_index(pid)
    x=get_hash(pid)
    y=get_finger_table(pid)
    p=get_numreq(pid)
    q=get_succ(pid)
    r=get_pred(pid)
    msg=get_msg(pid)


    neigh=Enum.map(y,fn x -> pid = :global.whereis_name(x)
                             pid end)
    succ=  :global.whereis_name(q)
    pred=  :global.whereis_name(r)
    update_succ_id(pid,succ)
    update_pred_id(pid,pred)
    update_finger_id(pid,neigh)
    s=get_succ_id(pid)
    t=get_pred_id(pid)
    u=get_finger_id(pid)
    mult=p*numN

    time1=System.monotonic_time(:millisecond)

    start_request(pid,x,msg,p,mult,0,numN,time1)

  end

  @doc """
  This function starts reuesting keys and handles hop count simultaneously handling node failure cases.
  """
  def start_request(pid,x,msg,count_msg,mult,tot_hops,numN,time) do

    [{_pid,{all}}] = Registry.match(Registry.MatchTest, "key", {:_})
    all_key= all -- get_msg(pid)
    if Enum.count(all_key) == 0 do
      #IO.puts("---empty---")
      tot_hops
    else
    key_req=Enum.random(all_key)
    fingers = get_finger_table(pid)
    node1=find_neighbor(fingers,key_req)
    #IO.inspect("my id #{inspect(pid)}")
    got_final = check_next_node(node1,key_req,pid,1,numN)
    [_head|tail]= got_final
    #final_msg = Enum.at(tail,0)    useful
    hops = Enum.at(tail,1)
    #IO.puts("node#{x} msg#{count_msg} : #{hops}")
    tot_hops = tot_hops + hops
    count_msg = count_msg - 1

    ## Node Failure cases implemented


    failure_prob = Enum.random(1..1000)
    temp_failure = rem(failure_prob,26)
    perm_failure = rem(failure_prob,25)
    check_fail_count = get_failure_count(pid)

    ####### temporary failure
    # In this case node's successor and predecessor are alerted that node is going to exit.
    # so the node's predecessor changes it's successor and the node's successor changes it's predecessor.
    # When node rejoins, similar procedure is carried out to stabilise the keys and set up the correct neighbor.
    if temp_failure == 0 && check_fail_count == 0 do
      #IO.puts("temporary failure")
      update_failure(pid)
      pred_hashr = get_pred(pid)
      succ_hashr = get_succ(pid)
      pred_idr = :global.whereis_name(pred_hashr)
      succ_idr = :global.whereis_name(succ_hashr)
      my_keys = get_msg(pid)
      update_msg_nodedel(succ_idr,my_keys)
      update_pred(succ_idr,pred_hashr)
      update_succ(pred_idr,succ_hashr)
      update_pred_id(succ_idr,pred_idr)
      update_succ_id(pred_idr,succ_idr)
      :global.unregister_name(x)
      :global.sync()

      ## Node destroyed
      :timer.sleep(Enum.random(1000..3000))
      ## Node rejoins
      :global.register_name(x,pid)
      :global.sync()
      #IO.puts("rejoined")

      # find your predecessor and successor
      current_nodes=Enum.sort(:global.registered_names())
      curr_size = Enum.count(current_nodes)
      new_predh = get_pred_rejoin(current_nodes,x,curr_size)
      new_succh = get_succ_rejoin(current_nodes,x,curr_size)
      new_pred_pid=:global.whereis_name(new_predh)
      new_succ_pid=:global.whereis_name(new_succh)
      # change your successors and predecessors
      update_pred(pid,new_predh)
      update_succ(pid,new_succh)
      update_pred_id(pid,new_pred_pid)
      update_succ_id(pid,new_succ_pid)
      # tell neigbhors to change their successors and predecessors
      update_pred(new_succ_pid,x)
      update_succ(new_pred_pid,x)
      update_pred_id(new_succ_pid,pid)
      update_succ_id(new_pred_pid,pid)
      # time to get keys from predecessor
      new_msg_rejoin = get_msg(new_succ_pid)
      my_new_msg = get_msg_rejoin(new_msg_rejoin,x)
      # now change succ keys. remove keys from succ that you got
      succ_new_keys = new_msg_rejoin -- my_new_msg
      set_msg(new_succ_pid,succ_new_keys)

end


  ## Permanent failure -- In this case node alerts it's predecessor and successor and dies
   if perm_failure == 0 do
      #IO.puts("permanent failure")
      update_failure(pid)
      pred_hashr = get_pred(pid)
      succ_hashr = get_succ(pid)
      pred_idr = :global.whereis_name(pred_hashr)
      succ_idr = :global.whereis_name(succ_hashr)
      my_keys = get_msg(pid)
      update_msg_nodedel(succ_idr,my_keys)
      update_pred(succ_idr,pred_hashr)
      update_succ(pred_idr,succ_hashr)
      update_pred_id(succ_idr,pred_idr)
      update_succ_id(pred_idr,succ_idr)
      :global.unregister_name(x)
      :global.sync()
      #IO.puts("killed #{inspect(pid)} with hash #{x} checking registry... #{inspect(:global.registered_names())}")
      0
    else

    #######

    #IO.puts("count_msg #{count_msg}")
    #IO.puts "I am process #{x} with keys #{inspect(msg) } requested key : #{key_req} from #{(head)} requested complpeted got : #{final_msg} in #{hops} hops"
    if count_msg > 0 do
      time1=System.monotonic_time(:millisecond)
      diff= time1 - time
      if diff < 1000 do
        :timer.sleep(1000 -(diff))
      end


      time1 = System.monotonic_time(:millisecond)


      start_request(pid,x,msg,count_msg,mult,tot_hops,numN,time1)
    else
    tot_hops
  end
 end
end

end

@doc """
Adjust node's predecessor when the node rejoins.
"""
 def get_pred_rejoin(list,x,size) do
   new_pred_list = Enum.filter(list,fn y ->  y < x  end)
   if Enum.count(new_pred_list) != 0 do
       Enum.max(new_pred_list)
    else
       Enum.at(list,size - 1)
   end
 end

 @doc """
 Adjust node's successor when the node rejoins.
 """
 def get_succ_rejoin(list,x,_size) do
   new_succ_list = Enum.filter(list,fn y ->  y > x  end)
   if Enum.count(new_succ_list) != 0 do
       Enum.max(new_succ_list)
    else
       Enum.at(list,0)
   end
 end

 def get_msg_rejoin(list,key) do
   Enum.filter(list,fn y -> y<=key  end)
 end

 @doc """
 This function starts checking chosen node's finger table. If the received element has the key then function returns current
 hop count else it continues to find to key.
 """
 def check_next_node(result,key_req,pid,hops,numN) do

#   IO.puts("result : #{result} key requested #{key_req} hops #{hops}")
   if hops>=numN do
     #IO.puts("shit")
     [result] ++ [-1] ++ [div(numN,2)]
     #System.halt(1)
   else

   if result == -1 do   #   null returned from finger table
   #IO.puts("here1 #{inspect(pid)}")

      s_hash=get_succ(pid)
      sid=:global.whereis_name(s_hash)
      flag = check_succ_keys(key_req,sid)
#      IO.puts("flag returned #{flag}")

      if flag == -1 do
        s_fing = get_finger_table(sid)             # now check finger table of successor
        node = find_neighbor(s_fing,key_req)
        hops=hops+1
    #    IO.puts("went to succ")
        check_next_node(node,key_req,sid,hops,numN)
      else
        [s_hash] ++ [flag] ++ [hops]
      end

   else   # finger table returned some node's hash
   #IO.puts("here2 #{inspect(pid)}")
      nid = :global.whereis_name(result)
      n_hash=result
      flag = check_node_keys(nid,key_req)

      if flag == -1 do
        n_fing = get_finger_table(nid)                          # now check finger table of node's hash
        node = find_neighbor(n_fing,key_req)
        hops=hops+1
        succ_hasht = get_succ(nid)
        succ_hasht_id = :global.whereis_name(succ_hasht)
        flag_t = check_succ_keys(key_req,succ_hasht_id)
        #IO.puts("went to next node")
        if flag_t != -1 do
         [succ_hasht] ++ [flag_t] ++[hops+1]
       else
        check_next_node(node,key_req,nid,hops,numN)
      end
      else
        [n_hash] ++ [flag] ++[hops]
      end

   end

 end
end

@doc """
This function checks if a node has the requested key or not. If the key is found, the corresponding message is returned else -1 is returned.
"""
 def check_node_keys(pid,key) do

   keys=get_msg(pid)
   x = Enum.filter(keys, fn z -> z == key  end)
   size=Enum.count(x)
   if size == 0 do
     -1
   else
    msg=request_message(key,pid)
    msg

   end


 end

 @doc """
 This function checks the node's successor, if that node has the key or not.If the key is found, the corresponding message is returned else -1 is returned.
 """

 def check_succ_keys(key,pid) do

   keys=get_msg(pid)
#   IO.puts("successor keys #{inspect(keys)}")
   x = Enum.filter(keys, fn z -> z == key  end)
#   IO.puts("filtered : #{Enum.at(x,0)}")
   size = Enum.count(x)
   if size == 0 do
     -1
   else
    msg=request_message(key,pid)
    msg

   end
 end

 def contact_node(key,pid) do
   fetch_key = request_message(key,pid)
   fetch_key
 end

 def find_neighbor(list,key) do
    list=Enum.sort(list)
    keys=Enum.filter(list,fn x ->    y =:global.whereis_name(x)
                                     x <= key && y != :undefined end)
  #                                   IO.puts("size of keys #{Enum.count(keys)}")

    #IO.puts("Size is #{Enum.count(keys)}")



    if Enum.count(keys) == 0 do
      -1
    else

     element=Enum.max(keys)
     element

    end

 end

  def init(:ok) do
      {:ok, {0,0,"12345",[],[],0,[],[],[],[],[],0}} #{nodeId,hash,IP,fingers,message,numreq,successor,predecessor,finger_id,succ_id,pred_id,failure_count}
  end


  def create_nodes(numNodes,hash,successor,fingers,pred,msg,req) do
    if numNodes > 0 do
      #IO.puts("node #{numNodes} created with hash #{Enum.at(hash,numNodes-1)}")
      nodeName = String.to_atom("node#{numNodes}")
      pid = start_link()#GenServer.start_link(Nodes, 1, name: nodeName)
      :global.register_name(Enum.at(hash,numNodes-1),pid)
      update_PID(pid,numNodes)
#      IO.inspect pid
      update_hash(pid,Enum.at(hash,numNodes-1))
      update_finger_list(pid,Enum.at(fingers,numNodes-1))
      update_succ(pid,Enum.at(successor,numNodes-1))
      update_pred(pid,Enum.at(pred,numNodes-1))
      update_req(pid,req)
      set_msg(pid,Enum.at(msg,numNodes-1))
      create_nodes(numNodes-1,hash,successor,fingers,pred,msg,req)
    end

  end
  def update_finger_list(pid,map) do
    GenServer.cast(pid, {:UpdateAdjacentState,map})
  end

  def update_finger_id(pid,map) do
    GenServer.cast(pid, {:UpdateAdjacentId,map})
  end

  def update_PID(pid,nodeID) do
    GenServer.cast(pid, {:update_PID,nodeID})
  end

  def update_hash(pid,hash) do
    GenServer.cast(pid, {:update_hash,hash})
  end

  def update_failure(pid) do
    GenServer.cast(pid, {:update_failure})
  end

  def get_index(pid) do
    GenServer.call(pid,{:getIndex})
  end

 def get_failure_count(pid) do
   GenServer.call(pid,{:get_failure_count})
 end

  def get_hash(pid) do
    GenServer.call(pid,{:getHash})
  end

  def get_finger_table(pid) do
    GenServer.call(pid,{:get_finger})
  end

  def get_finger_id(pid) do
    GenServer.call(pid,{:get_finger_id})
  end

  def update_msg(pid,msg) do
    GenServer.cast(pid, {:update_msg,msg})
  end

  def update_msg_nodedel(pid,msg) do
    GenServer.cast(pid, {:update_msg_nodedel,msg})
  end

  def set_msg(pid,msg) do
    GenServer.cast(pid, {:set_msg,msg})
  end

  def update_succ(pid,node) do
    GenServer.cast(pid, {:update_succ,node})
  end

  def update_succ_id(pid,node) do
    GenServer.cast(pid, {:update_succ_id,node})
  end

  def update_pred(pid,node) do
    GenServer.cast(pid, {:update_pred,node})
  end

  def update_pred_id(pid,node) do
    GenServer.cast(pid, {:update_pred_id,node})
  end

  def get_msg(pid) do
    GenServer.call(pid,{:getMsg})
  end

  def request_message(key,pid) do
    GenServer.call(pid,{:reqMsg,key})
  end

  def get_numreq(pid) do
    GenServer.call(pid,{:getNumReq})
  end

  def get_succ(pid) do
    GenServer.call(pid,{:getSucc})
  end

  def get_pred(pid) do
    GenServer.call(pid,{:getPred})
  end

  def get_succ_id(pid) do
    GenServer.call(pid,{:getSuccId})
  end

  def get_pred_id(pid) do
    GenServer.call(pid,{:getPredId})
  end

  def update_req(pid,req) do
    GenServer.cast(pid, {:update_req,req})
  end

  ########################################

  def handle_cast({:update_req,req} ,state) do
    {a,b,c,d,e,_f,g,h,i,j,k,l}=state
    state={a,b,c,d,e,req,g,h,i,j,k,l}
    {:noreply, state}
  end

  def handle_call({:getPredId}, _from ,state) do
    {_a,_b,_c,_d,_e,_f,g,h,i,j,k,l}=state
    {:reply,k, state}
  end

  def handle_call({:getSuccId}, _from ,state) do
    {_a,_b,_c,_d,_e,_f,_g,h,i,j,k,l}=state
    {:reply,j, state}
  end

  def handle_call({:getSucc}, _from ,state) do
    {_a,_b,_c,_d,_e,_f,g,h,i,j,k,l}=state
    {:reply,g, state}
  end

  def handle_call({:getPred}, _from ,state) do
    {_a,_b,_c,_d,_e,_f,_g,h,i,j,k,l}=state
    {:reply,h, state}
  end

  def handle_call({:getNumReq}, _from ,state) do
    {_a,_b,_c,_d,_e,f,_g,_h,_i,_j,_k,_l}=state
    {:reply,f, state}
  end

  def handle_call({:getMsg}, _from ,state) do
    {_a,_b,_c,_d,e,_f,_g,_h,_i,_j,_k,_l}=state
    {:reply,e, state}
  end

  def handle_call({:get_failure_count}, _from ,state) do
    {_a,_b,_c,_d,_e,_f,_g,_h,_i,_j,_k,l}=state
    {:reply,l, state}
  end

  def handle_cast({:update_failure} ,state) do
    {a,b,c,d,e,f,g,h,i,j,k,l} = state
    l = l + 1
    state={a,b,c,d,e,f,g,h,i,j,k,l}
    {:noreply, state}
  end

  def handle_call({:reqMsg,key}, _from ,state) do
    {_a,_b,_c,_d,e,_f,_g,_h,_i,_j,_k,_l}=state
    x = Integer.digits(key)
    word = Enum.join(Enum.map(x,fn y-> List.to_string([y+65]) end))

    {:reply,word, state}
  end

  def handle_cast({:update_succ,node} ,state) do
    {a,b,c,d,e,f,_g,h,i,j,k,l} = state
    state={a,b,c,d,e,f,node,h,i,j,k,l}
    {:noreply, state}
  end

  def handle_cast({:update_succ_id,node} ,state) do
    {a,b,c,d,e,f,g,h,i,_j,k,l} = state
    state={a,b,c,d,e,f,g,h,i,node,k,l}
    {:noreply, state}
  end

  def handle_cast({:update_pred,node} ,state) do
    {a,b,c,d,e,f,g,_h,i,j,k,l} = state
    state={a,b,c,d,e,f,g,node,i,j,k,l}
    {:noreply, state}
  end

  def handle_cast({:update_pred_id,node} ,state) do
    {a,b,c,d,e,f,g,h,i,j,_k,l} = state
    state={a,b,c,d,e,f,g,h,i,j,node,l}
    {:noreply, state}
  end

  def handle_cast({:update_msg,msg} ,state) do
    {a,b,c,d,e,f,g,h,i,j,k,l} = state
    e= e ++ [msg]
    state={a,b,c,d,e,f,g,h,i,j,k,l}
    {:noreply, state}
  end

  def handle_cast({:update_msg_nodedel,msg} ,state) do
    {a,b,c,d,e,f,g,h,i,j,k,l} = state
    e= e ++ msg
    state={a,b,c,d,e,f,g,h,i,j,k,l}
    {:noreply, state}
  end

  def handle_cast({:set_msg,msg} ,state) do
    {a,b,c,d,e,f,g,h,i,j,k,l} = state

    e =  msg
    state={a,b,c,d,e,f,g,h,i,j,k,l}
    {:noreply, state}
  end

  def handle_call({:get_finger}, _from ,state) do
    {_a,_b,_c,d,_e,_f,_g,_h,_i,_j,_k,_l}=state
    {:reply,d, state}
  end

  def handle_call({:get_finger_id}, _from ,state) do
    {_a,_b,_c,_d,_e,_f,_g,_h,i,_j,_k,_l}=state
    {:reply,i, state}
  end

  def handle_call({:getHash}, _from ,state) do
    {_a,b,_c,_d,_e,_f,_g,_h,_i,_j,_k,_l}=state
    {:reply,b, state}
  end

  def handle_call({:getIndex}, _from ,state) do
    {a,_b,_c,_d,_e,_f,_g,_h,_i,_j,_k,_l}=state
    {:reply,a, state}
  end

  def handle_cast({:update_hash,hash} ,state) do
    {a,_b,c,d,e,f,g,h,i,j,k,l} = state
    state={a,hash,c,d,e,f,g,h,i,j,k,l}
    {:noreply, state}
  end

  def handle_cast({:update_PID,nodeID} ,state) do
    {_a,b,c,d,e,f,g,h,i,j,k,l} = state
    state={nodeID,b,c,d,e,f,g,h,i,j,k,l}
    {:noreply, state}
  end

  def handle_cast({:UpdateAdjacentState,map}, state) do
    {a,b,c,_d,e,f,g,h,i,j,k,l}=state
    state={a,b,c,map,e,f,g,h,i,j,k,l}
    {:noreply, state}
  end

  def handle_cast({:UpdateAdjacentId,map}, state) do
    {a,b,c,d,e,f,g,h,_i,j,k,l}=state
    state={a,b,c,d,e,f,g,h,map,j,k,l}
    {:noreply, state}
  end

end

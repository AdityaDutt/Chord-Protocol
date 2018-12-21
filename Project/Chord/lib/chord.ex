defmodule Chord do
@moduledoc """
Chord module takes number of nodes and number of requests as input. Firstly, hash is calculated then it is truncated
to m bits. We then generate a unique identifier for each node, then create it's finger table of size m. Then, we spawn
each node. So, all the nodes run concurrently and independently, completing the requests that they have to make.
Each node has a genserver. We use registry to store hops of each node. When all the nodes are finished, we get values
from registry and calculate their average.
"""

  def hello(n,k) do
    numNodes = n
    numRequests = k
    s ="12345"
    y1= :crypto.hash(:sha256, s)|>Base.encode16()
    y= String.slice(y1,0..2)
    y=String.to_integer(y,16)
    m=round getm(y)
    #IO.puts("initial m : #{m}")
    m1= round :math.pow(2,m) - 1
    #IO.puts("initial m1 : #{m1}")
    m2 = check_m_value(m1,m,numNodes)
    #IO.puts ("m : #{m2}")
    m3= round :math.pow(2,m2) - 1
    #IO.puts ("m1 : #{m3}")
    m=m2
    m1=m3

    Registry.start_link(keys: :duplicate, name: Registry.MatchTest)
    Registry.start_link(keys: :duplicate, name: Registry.HopsTest)
    Registry.start_link(keys: :duplicate, name: Registry.Hop)
    nodes_hash2 = Enum.sort(Enum.map(1..10 *numRequests*numNodes, fn(_x)-> Enum.random(0..m1) end))
    nodes_hash1=Enum.uniq(nodes_hash2)
    nodes_hash=Enum.take(nodes_hash1,numNodes)
    nodes_hash=Enum.sort(nodes_hash)
    len=Enum.count(Enum.uniq(nodes_hash))
    #IO.puts("number of elements : #{len}")
    #IO.puts("number of requests : #{numRequests}")
    #IO.puts("m : #{m}")
    #IO.inspect nodes_hash
    keys = nodes_hash
    initial_nodes=nodes_hash
    min_key=Enum.min(nodes_hash)
    keys2=Enum.map(0..numNodes-1,fn y-> if y < numNodes - 1 do
                                        get_keys_between(Enum.at(nodes_hash,y),Enum.at(nodes_hash,y+1),numRequests,y)
                                      else
                                        get_keys_greater(Enum.at(nodes_hash,y),numRequests)
                                      end
                                       end)
    keys2=List.flatten(keys2)
    keys1 = Enum.map(1..numRequests*numNodes,fn(_x)-> Enum.random(min_key..m1) end)
    keys = keys ++ keys1 ++ keys2
    keys = Enum.sort(Enum.uniq(keys))
    Registry.register(Registry.MatchTest, "key", {keys})
    #IO.inspect keys
    #IO.puts("Total keys #{Enum.count(keys)}")
    successor = Enum.map(0..numNodes-1,fn(x)-> if x == numNodes-1 do
                                             Enum.at(nodes_hash,0)
                                           else
                                             Enum.at(nodes_hash,x+1)  end  end)
    pred = Enum.map(0..numNodes-1,fn(x)-> if x==0 do
                                         Enum.at(nodes_hash,numNodes-1)
                                        else
                                         Enum.at(nodes_hash,x-1)
                                        end         end)

    list =Enum.map(1..numNodes,fn(x)->hash=Enum.at(nodes_hash,x-1)
                   Enum.map(1..m,fn(y)->  rem( (hash + round :math.pow(2,y-1) ),round :math.pow(2,m) ) end)   end)
    nodes_sort=Enum.sort(nodes_hash)
    rm=Enum.random(1200..1800)
    list1 = Enum.map(1..numNodes,fn x->   get_finger(nodes_sort,Enum.at(list,x-1))  end)
    msg=Enum.map(1..numNodes,fn x-> get_keys(x,Enum.at(nodes_hash,x-1),Enum.at(pred,x-1),keys)   end)
    rm = round rm/100 * numNodes
    temp_msg=List.flatten(msg)
    temp_msg_count=Enum.count(temp_msg)
    #IO.puts("keys assigned #{temp_msg_count}")
    #IO.inspect msg
    rm=rm+1
    Nodes.create_nodes(numNodes,nodes_hash,successor,list1,pred,msg,numRequests)
    :global.sync()

    time_begin=System.monotonic_time(:millisecond)
    record = :ets.new(:record, [:duplicate_bag,:public])

    :ets.insert(record, {"count",0})

    Registry.register(Registry.Hop,"out",{0})
    pz = Enum.map(nodes_hash,fn x ->  spawn fn-> y = Nodes.begin(:global.whereis_name(x),numNodes)
         #IO.inspect y
    :ets.insert(record, {"count",y})

       end

         end)


    Enum.each(pz,fn x ->   ref = Process.monitor(x)
      receive do
      {:DOWN, ^ref, _, _, _} ->#IO.puts "Process #{inspect(x)} is down"

      end
      end)

    list_count = :ets.lookup(record, "count")
    #IO.inspect list_count

    time_end=System.monotonic_time(:millisecond)

    size=Enum.count(list_count)
    hops_array = Enum.map(1..size,fn x -> {_,val} = Enum.at(list_count,x-1)
                                                 val
                                        #         IO.inspect val
                                               end)
    total_hops = Enum.sum(hops_array)
    denominator = numNodes * numRequests
    avg = total_hops/denominator
    IO.puts("Average hops : #{total_hops} / #{denominator} = #{avg} in #{time_end - time_begin} milliseconds")

    System.halt(1)
  end

  @doc """
  This function generates keys between two given node hash values.
  """
 def get_keys_between(n1,n2,count,_y1) do
   #IO.puts("keys between #{n1} and #{n2} with count #{count} loop #{y1}")
   keys = Enum.map(1..2*count,fn x-> Enum.random(n1..n2) end)
   keys = Enum.uniq(keys)
   keys
 end

 @doc """
 This function generates keys larger than a given node hash value. It is called for the last node or the node with max hash.
 """
 def get_keys_greater(n,count) do
   #IO.puts("keys greater #{n}")
   limit= n * 3
   keys = Enum.map(1..2*count,fn x-> Enum.random(n..limit)  end)
   keys = Enum.uniq(keys)
   keys
 end

 @doc """
 This function returns keys between two given node hash values.
 """
 def get_keys(ind,node1,node2,keys) do

   list=Enum.filter(keys,fn x ->if ind != 1 do
                                 x<=node1 && x>node2
                                else
                                  x==node1 || x>node2
                                end
   end)
   list
 end

@doc """
Get finger table of a node
"""
  def get_finger(all,list) do
     list1=Enum.map(list,fn x-> check_finger(x,all)  end)
     list1

  end

@doc """
Get max element from finger table of a node which is less than key, if exists
"""

  def check_finger(num,all) do
     s = Enum.find_index(all,fn(x)->  x >= num end )
     if s==nil do
       res=Enum.at(all,0)
       res
    else
     res=Enum.at(all,s)
     res
     end
  end

  def getm(x) when x>15 do
   z=  Enum.random(120..155)
   div(z,10)
  end

  def getm(x) when x<=15 do
    x
  end

  def check_m_value(m1,m,n) do
    if m1 < n do
      m = m + 1
      m1= round :math.pow(2,m) - 1
      check_m_value(m1,m,n)
    else
     m
    end

  end

end

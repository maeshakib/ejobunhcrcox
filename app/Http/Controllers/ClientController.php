<?php

namespace App\Http\Controllers;
use App\Client;
use App\User;
use Illuminate\Validation\Rule;
use Validator;
use Illuminate\Http\Request;

class ClientController extends Controller
{
    public function index()
    { 
         $user= auth('api')->user();
       //$user=User::find($user->id);
      // $user=User::find(5);
       //get all clients
       $all_client = Client::where('user_id',$user->id)->orderBy('id','desc')->get();
    //    $all_client['total_client']=$all_client->count('id');
    //    $all_client['active']=$all_client->where('status',1)->count();

       if ($all_client)
       {
           return response()->json(['success' => true,'clients'=>$all_client] ,200);
       }
       else{
               return response()->json([
                   'success' => false,
                   'message' => 'Sorry,no client found'
               ], 200);
           }

    }


    public function store(Request $request)
    {
        $user= auth('api')->user();
        $rules = array(
            'name' => 'required|max:190',
            'conatct_no' => 'required',
            'status' => 'digits_between:0,1',
        );
        $messages=array(
            'name.required' => 'Please enter a Name.',
            'conatct_no.required' => 'Please enter a Contact NO.',
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors(),
            );
            return response()->json($returnMessage, 200);
        }
        $client = new Client;
        $client->name = $request->name;
        $client->conatct_no = $request->conatct_no;
        $client->lat_lng = $request->lat_lng;
        $client->address = $request->address;
        $client->user_id = $user->id;
        $client->location_area_id = $user->location_area_id;
        if($request->has('status'))
        {
            $client->status = $request->status;
            
        }else{
            $client->status = 1;
        }
        $client->description = $request->description;
        $saved=$client->save();

        if ($saved)
        {
            return response()->json(['success' => true, 'message' =>'Client Saved Successfully '], 200);             
        }else{
            return response()->json(['success' => false, 'message' =>'Client Information has not been Saved '], 200);
        }

    }

    public function show($id)
    {
        $client = Client::find($id);


        if (!$client) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Client with id ' . $id . ' cannot be found'
            ], 200);
        }else
        {
           
            return response()->json([
                'success' => true,
                'client' => $client
            ]);
        }

    }

 

    public function update(Request $request, $id)
    {
        $user= auth('api')->user();

        $rules = array(
            'name'       => 'required|max:190',      
            'status' => 'digits_between:0,1',
        );
        $messages=array(
            'name.required' => 'Please enter a Name.',
            'status' => 'digits_between:0,1',

        );

  


        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors(),
            );
            return response()->json($returnMessage, 200);
        }
        
        $client = Client::find($id);

        if (!$client) {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Client with id ' . $id . ' cannot be found'
            ], 200);
        }
      $client->name = $request->name;
        $client->conatct_no = $request->conatct_no;
        $client->lat_lng = $request->lat_lng;
        $client->address = $request->address;
        $client->status = $request->status;
        $client->description = $request->description;
        // 'name','conatct_no','lat_lng','address',''
        $updated = $client->save();

        if ($updated) {
            return response()->json([ 'success' => true, 'message' => 'Client Updated Successfully']);
        } else {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Client could not be updated'
            ], 200);
        }

    }


    /**
     * Remove the specified resource from storage.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy($id)
    {
        $client = Client::find($id);

        if (!$client) {
         return response()->json([
             'success' => false,
             'message' => 'Sorry, Client with id ' . $id . ' cannot be found'
         ], 200);
        }

        if ($client->delete()) {
         return response()->json([
             'success' => true,
             'message' => 'Client Deleted Successfully'
         ]);
        } 
        else {
         return response()->json([
             'success' => false,
             'message' => 'Client could not be deleted'
         ], 200);
        }

    }
}

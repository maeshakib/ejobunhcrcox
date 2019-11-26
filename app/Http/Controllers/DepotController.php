<?php

namespace App\Http\Controllers;
use App\Depot;
use Validator;
use Illuminate\Validation\Rule;

use Illuminate\Http\Request;

class DepotController extends Controller
{
    public function index()
    {
        //get all depots
        $all_department = Depot::all();
        if ($all_department)
        {
            return response()->json([
                'success' => true,
                'depots' => $all_department
            ]);
        }
        else{
                return response()->json([
                    'success' => false,
                    'message' => 'Sorry,no Deport found'
                ], 500);
            }

    }


    public function store(Request $request)
    {
        $rules = array(
            'name' => 'required|max:190|unique:depots'
        );
        $messages=array(
            'name.required' => 'Please enter a Name.'
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
        $department = new Depot;
        $department->name = $request->name;
        $department->description = $request->description;
        $saved=$department->save();

        if ($saved)
        {
            $all_department = Depot::all(['id','name']);

            return response()->json([
                'success' => true,
                'depots' => $all_department
            ], 200);
        }




    }

    public function show($id)
    {
        $department = Depot::find($id);


        if (!$department) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Deport with id ' . $id . ' cannot be found'
            ], 400);
        }else
        {
            return response()->json($department);
        }

    }

    

    public function update(Request $request, $id)
    {
        $rules = array(
            'name'       => [
                'required',
                Rule::unique('depots', 'name')->ignore($id),            ],  
        );
        $messages=array(
            'name.required' => 'Please enter a Name.'
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
            'success' => false,
            'errors' => $validator->errors(),
            );
            return response()->json($returnMessage, 403);
        }
        
        $department = Depot::find($id);

        if (!$department) {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Deport with id ' . $id . ' cannot be found'
            ], 400);
        }


        $updated = $department->fill($request->all())
        ->save();

        if ($updated) {
            return response()->json([
                'success' => true
            ]);
        } else {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Deport could not be updated'
            ], 500);
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
        $department = Deport::find($id);

        if (!$department) {
         return response()->json([
             'success' => false,
             'message' => 'Sorry, Deport with id ' . $id . ' cannot be found'
         ], 400);
        }

        if ($department->delete()) {
         return response()->json([
             'success' => true
         ]);
        } 
        else {
         return response()->json([
             'success' => false,
             'message' => 'Deport could not be deleted'
         ], 500);
        }

    }
}

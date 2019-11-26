<?php

namespace App\Http\Controllers;
use Validator;

use Illuminate\Http\Request;
use App\Designation;
use Illuminate\Validation\Rule;

class DesignationController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
       Version      :v.1
       T-Code       :d-t-mvc:1-21-21-21-21
       Description  : display all Designation
     */
    public function index()
    {
        //get all designations
        $all_designation = Designation::all();
        if ($all_designation)
        {
            return response()->json([
                'success' => true,
                'designations' => $all_designation
            ]);
        }
        else{
                return response()->json([
                    'success' => false,
                    'message' => 'Sorry,no designation found'
                ], 500);
            }

    }

    /**
     * @return \Illuminate\Http\Response
       Version      :v.1
       T-Code       :
       Description  : insert new Designation
    */
    public function store(Request $request)
    {
        $rules = array(
            'name' => 'required|max:190|unique:designations'
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
        $designation = new Designation;
        $designation->name = $request->name;
        $designation->description = $request->description;
        $saved=$designation->save();

        if ($saved)
        {
            $all_designation = Designation::all(['id','name']);

            return response()->json([
                'success' => true,
                'designations' => $all_designation
            ], 200);
        }

    }


    /**
     * Display the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show($id)
    {
        $designation = Designation::find($id);
        return response()->json($designation);
    }


    /**
     * Update the specified resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function update(Request $request, $id)
    {
        $rules = array(
            'name'       => [
                'required',
                Rule::unique('designations', 'name')->ignore($id),            ],  
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
        
        $designation = Designation::find($id);

        if (!$designation) {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Designation with id ' . $id . ' cannot be found'
            ], 400);
        }


        $updated = $designation->fill($request->all())
        ->save();

        if ($updated) {
            return response()->json([
                'success' => true
            ]);
        } else {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Designation could not be updated'
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
        $designation = Designation::find($id);

        if (!$designation) {
         return response()->json([
             'success' => false,
             'message' => 'Sorry, Designation with id ' . $id . ' cannot be found'
         ], 400);
        }

        if ($designation->delete()) {
         return response()->json([
             'success' => true
         ]);
        } 
        else {
         return response()->json([
             'success' => false,
             'message' => 'Designation could not be deleted'
         ], 500);
        }

    }
}

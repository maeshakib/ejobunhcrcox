<?php

namespace App\Http\Controllers;
use App\Department;
use Validator;
use Illuminate\Validation\Rule;

use Illuminate\Http\Request;

class DepartmentController extends Controller
{
    public function index()
    {
        //get all departments
        $all_department = Department::all();
        if ($all_department)
        {
            return response()->json([
                'success' => true,
                'departments' => $all_department
            ]);
        }
        else{
                return response()->json([
                    'success' => false,
                    'message' => 'Sorry,no department found'
                ], 500);
            }

    }


    public function store(Request $request)
    {
        $rules = array(
            'name' => 'required|max:190|unique:departments'
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
        $department = new Department;
        $department->name = $request->name;
        $department->description = $request->description;
        $saved=$department->save();

        if ($saved)
        {
            $all_department = Department::all(['id','name']);

            return response()->json([
                'success' => true,
                'departments' => $all_department
            ], 200);
        }




    }

    public function show($id)
    {
        $department = Department::find($id);


        if (!$department) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Department with id ' . $id . ' cannot be found'
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
                Rule::unique('departments', 'name')->ignore($id),            ],  
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
        
        $department = Department::find($id);

        if (!$department) {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Department with id ' . $id . ' cannot be found'
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
                'message' => 'Sorry, Department could not be updated'
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
        $department = Department::find($id);

        if (!$department) {
         return response()->json([
             'success' => false,
             'message' => 'Sorry, Department with id ' . $id . ' cannot be found'
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
             'message' => 'Department could not be deleted'
         ], 500);
        }

    }
}

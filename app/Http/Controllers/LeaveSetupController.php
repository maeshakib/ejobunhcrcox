<?php

namespace App\Http\Controllers;

use DB;
use Validator;
use App\LeaveApplication;
use App\Leave;
use App\User;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class LeaveSetupController extends Controller
{
    /**
     * Display a listing of the resource.
     *
     * @return \Illuminate\Http\Response
     */
    public function index()
    {
        $leaves = Leave::all();
        return response()->json($leaves, 200);
    }

    /**
     * Store a newly created resource in storage.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return \Illuminate\Http\Response
     */
    public function store(Request $request)
    {
        $rules = array(
            'name'       => 'required|max:190|unique:leaves',
            'carry_forward' => [
                'required',
                Rule::in([0, 1]),
            ],
            'total_amount' => 'required|integer',
            'gender_specific' => Rule::in([0, 1, null]), // 0 = only female, 1 = only male, null = all
            'jan' => 'required|integer',
            'feb' => 'required|integer',
            'mar' => 'required|integer',
            'apr' => 'required|integer',
            'may' => 'required|integer',
            'jun' => 'required|integer',
            'jul' => 'required|integer',
            'aug' => 'required|integer',
            'sep' => 'required|integer',
            'oct' => 'required|integer',
            'nov' => 'required|integer',
            'dec' => 'required|integer'
        );
        $messages=array(
            'name.required' => 'Please enter a Name.'
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            // $err = collect();
            // foreach ($validator->errors()->toArray() as $key => $value) {
            //     $err->put($key,$value[0]); 
            // }
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
                'message'       => 'Oops!!'
            
            );
            
            return response()->json($returnMessage, 200);
        }
        if($request->carry_forward == 1 && Leave::where('carry_forward', 1)->exists()){
            $returnMessage = array(
                'success' => false,
                'errors' => ['carry_forward' => 'You cannot add 2 Carry forwarded Leaves']
            );
            return response()->json($returnMessage, 200);
        }
        $leave = new Leave;
        //$leave = $request->get();
        $leave->fill($request->all())->save();
        $returnMessage = array(
            'success' => true,
            'message' => 'Saved Successfully'
        
        );
        return response()->json($returnMessage, 200);

    }

    /**
     * Display the specified resource.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function show($id)
    {
        $leave = Leave::find($id);
        return response()->json($leave, 200);
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
            'name'       => 'required|max:190|unique:leaves,name,'.$id,
            'carry_forward' => [
                'required',
                Rule::in([0, 1]),
            ],
            'total_amount' => 'required|integer',
            'gender_specific' => Rule::in([0, 1, null]), // 0 = only female, 1 = only male, null = all
            'jan' => 'required|integer',
            'feb' => 'required|integer',
            'mar' => 'required|integer',
            'apr' => 'required|integer',
            'may' => 'required|integer',
            'jun' => 'required|integer',
            'jul' => 'required|integer',
            'aug' => 'required|integer',
            'sep' => 'required|integer',
            'oct' => 'required|integer',
            'nov' => 'required|integer',
            'dec' => 'required|integer'
        );
        $messages=array(
            'name.required' => 'Please enter a Name.'
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            // $err = collect();
            // foreach ($validator->errors()->toArray() as $key => $value) {
            //     $err->put($key,$value[0]); 
            // }
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
                'message'       => 'Oops!!'
            
            );
            return response()->json($returnMessage, 406);
        }
        $leave = Leave::find($id);
        if($request->carry_forward == 1 && Leave::where('carry_forward', 1)->exists() && $leave->carry_forward != 1){
            $returnMessage = array(
                'success' => false,
                'errors' => ['carry_forward' => 'You cannot add 2 Carry forwarded Leaves']
            );
            return response()->json($returnMessage, 200);
        }
        //$leave = $request->get();
        $leave->fill($request->except(['_method', 'id']))->save();
        $returnMessage = array(
            'success' => true,
            'message' => 'Updated Successfully'
        
        );
        return response()->json($returnMessage, 200);
    }

    /**
     * Remove the specified resource from storage.
     *
     * @param  int  $id
     * @return \Illuminate\Http\Response
     */
    public function destroy($id)
    {
        $leave = Leave::find($id);

        if(LeaveApplication::where('leave_id', $id)->exists())
        {
            $returnMessage = array(
                'success' => false,
                'errors' => $leave->name.' Has Already been Used!!'
            );
            return response()->json($returnMessage, 200);
        }

        $leave->delete();
        $returnMessage = array(
            'success' => true,
            'message' => 'Deleted Successfully'
        
        );
        return response()->json($returnMessage, 200);
    }
}

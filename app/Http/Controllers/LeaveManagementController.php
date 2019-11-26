<?php

namespace App\Http\Controllers;

use DB;
use Validator;
use App\LeaveApplication;
use App\Leave;
use App\User;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class LeaveManagementController extends Controller
{
    /*
    *
    * Leave Application Submit 
    */
    public function leaveApplication(Request $request)
    {
        //return response()->json('ok', 200);
        $user= auth('api')->user();
        $rules = array(
            'from_date' => 'required|date',
            'to_date' => 'required|date|after_or_equal:from_date',
            'leave_id' => 'required|exists:leaves,id',
            'reason' => 'required|max:150',
            'description' => 'present'
            
        );
        $messages=array(
            'reason.required' => 'Please Specify a Reason',
            'leave_id.required' => 'Please Select Leave Type'
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
                'message'       => 'Oops!!'
            
            );
            return response()->json($returnMessage, 406);
        }
        
        if(LeaveApplication::where('user_id', $user->id)
        ->whereRaw('((? BETWEEN from_date AND to_date) OR (from_date BETWEEN ? AND ?))', 
        [$request->from_date, $request->from_date, $request->to_date])
        ->exists())
        {
            $returnMessage = array(
                'success' => false,
                'errors' => ['from_date' => ['You Already applied for this date']],
            );
            return response()->json($returnMessage, 406);
        }
        $diff = date_diff(date_create($request->from_date), date_create($request->to_date));

        $leaveApplication = new LeaveApplication;
        $leaveApplication->reason = $request->reason;
        $leaveApplication->description = $request->description;
        $leaveApplication->user_id = $user->id;
        $leaveApplication->leave_id = $request->leave_id;
        $leaveApplication->from_date = $request->from_date;
        $leaveApplication->to_date = $request->to_date;
        $leaveApplication->total_days = $diff->days + 1;
        $leaveApplication->save();

        $returnMessage = array(
            'success' => true,
            'message' => 'Updated Successfully'
        );
        return response()->json($returnMessage, 200);
    }

    /*
    *
    * Edit My Leave Application
    */

    public function updateMyLeaveApplication(Request $request, $id)
    {
        //return response()->json('ok', 200);
        $user= auth('api')->user();
        $rules = array(
            'from_date'       => 'required|date',
            'to_date'       => 'required|date|after_or_equal:from_date',
            'leave_id'       => 'required|exists:leaves,id',
            'reason' => 'required|max:150',
            'description' => 'present'
            
        );
        $messages=array(
            'reason.required' => 'Please Specify a Reason',
            'leave_id.required' => 'Please Select Leave Type'
        );
        $validator = Validator::make($request->all(), $rules, $messages);
        if($validator->fails())
        {
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
                'message'       => 'Oops!!'
            
            );
            return response()->json($returnMessage, 406);
        }
        if(LeaveApplication::where('user_id', $user->id)
        ->where('id', '!=', $id)
        ->whereRaw('((? BETWEEN from_date AND to_date) OR (from_date BETWEEN ? AND ?))', 
        [$request->from_date, $request->from_date, $request->to_date])
        ->exists())
        {
            $returnMessage = array(
                'success' => false,
                'errors' => ['from_date' => ['You Already applied for this date']],
            );
            return response()->json($returnMessage, 406);
        }
        $diff = date_diff(date_create($request->from_date), date_create($request->to_date));

        $leaveApplication = LeaveApplication::find($id);
        if($user->id != $leaveApplication->user_id){
            $returnMessage = array(
                'success' => false,
                'errors' => 'Update your Own Leave!!'
            );
            return response()->json($returnMessage, 200);
        }
        if($leaveApplication->is_approved > 0){
            $returnMessage = array(
                'success' => false,
                'errors' => 'This Application is not Pending!!!'
            );
            return response()->json($returnMessage, 200);
        }
        $leaveApplication->reason = $request->reason;
        $leaveApplication->description = $request->description;
        $leaveApplication->leave_id = $request->leave_id;
        $leaveApplication->from_date = $request->from_date;
        $leaveApplication->to_date = $request->to_date;
        $leaveApplication->total_days = $diff->days + 1;
        $leaveApplication->save();
        $returnMessage = array(
            'success' => true,
            'message' => 'Updated Successfully'
        );
        return response()->json($returnMessage, 200);
    }

    /*
    *
    * Delete My Leave Application
    */

    public function deleteMyLeaveApplication($id)
    {
        //return response()->json('ok', 200);
        $user= auth('api')->user();
        $leaveApplication = LeaveApplication::find($id);
        if($user->id != $leaveApplication->user_id){
            $returnMessage = array(
                'success' => false,
                'errors' => 'Delete your Own Leave!!'
            );
            return response()->json($returnMessage, 200);
        }
        if($leaveApplication->is_approved > 0){
            $returnMessage = array(
                'success' => false,
                'errors' => 'This Application is not Pending!!!'
            );
            return response()->json($returnMessage, 200);
        }

        $leaveApplication->delete();
        
        $returnMessage = array(
            'success' => true,
            'message' => 'Deleted Successfully'
        );
        return response()->json($returnMessage, 200);
    }

    /*
    *
    * Logged Users This year's total leave taken in specific leave type and remaining balance 
    */

    public function myLeaves()
    {
        $user= auth('api')->user();
        $joinDate = date_create($user->join_date);
        $data =  DB::select('CALL UserCurrentLeaveDetails(?)', [$user->id]);

        return response()->json($data, 200);
    }

    /*
    *
    * all Leaves taken by Logged User
    */

    public function myLeaveHistory()
    {
        $user= auth('api')->user();
        $leaves = LeaveApplication::with(['leave_type:id,name', 'approved_by:id,name'])->where('user_id', $user->id)->get();
        return response()->json($leaves, 200);
    }

    /*
    *
    * List of pending leave application if logged users is Supervisor
    */
    public function waitingForApproval()
    {
        $user= auth('api')->user();
        $leaveApplications = DB::select('
        SELECT la.*, u.name as applicant_name, l.name as leave_type_name FROM leave_applications la
        JOIN users u on u.id = la.user_id AND u.supervisor_id = ?
        JOIN leaves l on la.leave_id = l.id
        WHERE la.is_approved = 0',
        [$user->id]);
        return response()->json($leaveApplications, 200);
    }

    /*
    *
    * Approve or reject Leave Application
    */

    public function update(Request $request, $id)
    {
        $user= auth('api')->user();
        $rules = array(
            'is_approved'       => [
                'required',
                Rule::in([1, 2]), // 1. Approve, 2. Reject
            ],
            'remarks' => 'present'
        );
        $messages=array(
            'is_approved.required' => 'This field is required'
            
        );
        $validator = Validator::make($request->all(), $rules, $messages);

        if ($validator->fails()) {
            
            $returnMessage = array(
                'success' => false,
                'errors' => $validator->errors(),
                'message'       => 'Oops!!'
                
                );
                return response()->json($returnMessage, 403);
                
        }
        $returnMessage = array(
            'success' => true,
            'message'       => 'Updated'
            );
        $leaveApplication = LeaveApplication::find($id);
        if($leaveApplication){
            $applicant = User::find($leaveApplication->user_id);
            if($applicant->supervisor_id == $user->id && $leaveApplication->is_approved == 0){
                $leaveApplication->is_approved = $request->is_approved;
                $leaveApplication->remarks = $request->remarks;
                $leaveApplication->approved_by = $user->id;
                $leaveApplication->save();
                return response()->json($returnMessage, 200);
            }
            $returnMessage['success'] = false;
            $returnMessage['message'] = 'Not Authorised!!';
            return response()->json($returnMessage, 200);
        }
        $returnMessage['success'] = false;
        $returnMessage['message'] = 'Leave Application Not Found!!';
        return response()->json($returnMessage, 200);
    }

    


    /*
    *
    * Add remaining recurring leave to every user.  to be executed every year once.
    */
    public function updateAllUserRecurringLeave()
    {
        $user= auth('api')->user();
        $success = DB::select('CALL UpdateYearlyRecurringLeave(?)', [$user->id]);
        return response()->json(array_pop($success));
    }
}

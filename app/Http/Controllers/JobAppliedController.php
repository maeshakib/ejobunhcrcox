<?php
namespace App\Http\Controllers;

use App\JobApplied;
use App\JobPost;
use Validator;
use Illuminate\Validation\Rule;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;


class JobAppliedController extends Controller
{
    public function index()
    {
        //get all departments
        $job_applied = JobApplied::all();
        if ($job_applied)
        {
            return response()->json([
                'success' => true,
                'applied_job' => $job_applied
            ]);
        }
        else{
                return response()->json([
                    'success' => false,
                    'message' => 'Sorry,no Job found'
                ], 500);
            }

    }



    public function store(Request $request, $id)
    {
        $job_data = JobPost::find($id);

       
      //  return $request;
        $user= auth('api')->user();
        // $rules = array(
        //     'job_title' => 'required',    
                            
        // );
        // $messages=array(
        //     'job_title.required' => 'Course title required',         

        // );
        // $validator = Validator::make($request->all(), $rules, $messages);
        // if($validator->fails())
        // {
        //     $returnMessage = array(
        //     'success' => false,
        //     'errors' => $validator->errors(),
        //     );
        //     return response()->json($returnMessage, 200);
        // }

  
        $jobApply = new JobApplied;
        
        $jobApply->jobeeker_user_id = $user->id;       
        $jobApply->job_post_id   = $job_data->id;
        $jobApply->job_title   = $job_data->job_title;
        $jobApply->position_number   = $job_data->position_number;
        $jobApply->email   = $user->email;
        $jobApply->created_at   = now();
        
        $saved=$jobApply->save();

        if ($saved)
        {
          return response()->json([
                'success' => true,
            ], 200);
        }




    } //end store function

}

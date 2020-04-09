<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\JobPost;
use App\User;
use App\Education;


use App\JobApplied;
use DB;
use Validator;
use Illuminate\Validation\Rule;
use Illuminate\Support\Facades\Auth;
class JobPostController extends Controller
{
    public function index()
    {
        //get all departments
        $job_applied = JobPost::all();
        if ($job_applied)
        {
            return response()->json([
                'success' => true,
                'all_posted_job' => $job_applied
            ]);
        }
        else{
                return response()->json([
                    'success' => false,
                    'message' => 'Sorry,no Job found'
                ], 500);
            }

    } //end index function

    
    public function store(Request $request)
    {
        
       
      //  return $request;
        $user= auth('api')->user();
        $rules = array(
            'job_title' => 'required',
            'vacancy_notice' => 'required',       
            'position_number' => 'required', 
            'position_grade' => 'required', 
            'closing_date' => 'required', 
            'organizational_context' => 'required', 
            'responsibilities' => 'required', 
            'accountability_and_authority' => 'required', 
            'minimum_qualification' => 'required', 
                            
        );
        $messages=array(
            'job_title.required' => 'Course title required',
            'vacancy_notice.required' => 'Please enter a school name.',    
            'position_number.required' => 'Please enter a school name.',           
            'position_grade.required' => 'Please enter a school name.',           
            'closing_date.required' => 'Please enter a school name.',           
            'organizational_context.required' => 'Please enter a school name.',           
            'responsibilities.required' => 'Please enter a school name.',           
            'accountability_and_authority.required' => 'Please enter a school name.',           
            'minimum_qualification.required' => 'Please enter a school name.',           

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

  
        $newJobPost = new JobPost;
        $newJobPost->job_title = $request->job_title;
        $newJobPost->position_number = $request->position_number;  
        $newJobPost->location = $request->location;
        $newJobPost->position_grade = $request->position_grade;  
        $newJobPost->closing_date = $request->closing_date;
        $newJobPost->organizational_context = $request->organizational_context;  
        $newJobPost->responsibilities = $request->responsibilities;  
        $newJobPost->accountability_and_authority = $request->accountability_and_authority;  
        $newJobPost->minimum_qualification = $request->minimum_qualification;  

        
        // $training_sv->jobseeker_id = $user->id;       
        $newJobPost->created_at   = now();
        $saved=$newJobPost->save();

        if ($saved)
        {
          return response()->json([
                'success' => true,
            ], 200);
        }




    } //end store function


//get all cv of a single job
    public function singleJobAllCv($id)
    {
      // DB::enableQueryLog();
//        $q = JobApplied::join('users', 'job_applieds.jobeeker_user_id', '=', 'users.id');
// $q->join('educations', 'users.id', '=', 'educations.jobseeker_id')
// ->where('job_applieds.job_post_id', '=', 1)

// ->select(['job_applieds.job_title as job_applieds.job_title',
// 'users.name as users.name','educations.degree_title as educations.degree_title']);
// return $q->get();


    // return  $singleJobAllCvData=   DB::table('job_applieds AS ja')
     
    //    ->join("users as u",function($join){
    //     $join->on("u.id",'=','ja.jobeeker_user_id')
    //     ->on("work_experiences.jobseeker_id","=","u.id");


    // })
    // ->where('ja.job_post_id',1)

    //   ->select(
    //            'ja.jobeeker_user_id','ja.job_post_id',
    //        'ja.job_title','ja.position_number','u.name','u.first_name','u.middle_name','u.last_name',
    //         'u.email','u.mobile_no','u.photo','u.p11form','u.coverLetter')->get();

    //   $singleJobAllCvData=   DB::table('job_applieds AS ja')
    //     ->join('users AS u', function ($join) use($id)  {
    //        $join->on('u.id', '=' , 'ja.jobeeker_user_id') ;
    //        $join->where('ja.job_post_id',1);
    //    })
    //    ->select(
    //        'ja.jobeeker_user_id','ja.job_post_id',
    //    'ja.job_title','ja.position_number','u.name','u.first_name','u.middle_name','u.last_name',
    //    'u.email','u.mobile_no','u.photo','u.p11form','u.coverLetter')->get();
    


       $singleJobAllCvData = DB::select('SELECT 
       ja.jobeeker_user_id,
       ja.job_post_id,
       ja.job_title,
       ja.position_number,
       u.name,
       u.first_name,
       u.middle_name,
       u.last_name,
       u.email,
       u.mobile_no,
       u.photo,
       u.p11form,
       u.coverLetter,
       ifnull(sum(we.duration), 0) AS work_duration 

       from job_applieds  ja
       left join users  u  ON u.id = ja.jobeeker_user_id and ja.job_post_id=:job_id
       left  JOIN work_experiences  we on we.jobseeker_id = u.id' 
     ,

       ['job_id' => $id]);

    //   // dd(DB::getQueryLog());

        if (!$singleJobAllCvData) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Job with id ' . $id . ' cannot be found'
            ], 400);
        }else
        {
            return response()->json($singleJobAllCvData);
        }

    }

    public function singleJobShortlistedCv($id)
    {
   
       $singleJobShortlistCvData = DB::select('SELECT 
       ja.jobeeker_user_id,
       ja.job_post_id,
       ja.job_title,
       ja.position_number,
       u.name,
       u.first_name,
       u.middle_name,
       u.last_name,
       u.email,
       u.mobile_no,
       u.photo,
       u.p11form,
       u.coverLetter,
       ifnull(sum(we.duration), 0) AS work_duration 

       from job_applieds  ja
       left join users  u  ON u.id = ja.jobeeker_user_id and ja.job_post_id=:job_id
       JOIN work_experiences  we on we.jobseeker_id = u.id' 
     ,

       ['job_id' => $id]);
     



      // dd(DB::getQueryLog());

        if (!$singleJobShortlistCvData) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Job with id ' . $id . ' cannot be found'
            ], 400);
        }else
        {
            return response()->json($singleJobShortlistCvData);
        }

    }
  //save short list  
    public function shortListUser( Request $request)
    {
      //  return $request->user_id;
        $saved=   DB::table('job_applieds')
        ->where('jobeeker_user_id', 1)
        ->where('job_post_id', 1)
        ->update(['shortlisted'=>1]);
    


        if (!$saved) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Job with id ' . $jobid . ' cannot be found'
            ], 400);
        }else
        {
            return response()->json([
                'success' => true,
            ], 200);
        }


    } //end store function 
}
//end class

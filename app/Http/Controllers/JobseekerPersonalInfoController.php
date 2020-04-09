<?php

namespace App\Http\Controllers;

use JWTAuth;

use DB;
use App\User;
use App\Role;
use App\Depot;
use Validator;
use App\RolePermission;
use App\JobseekerPersonalInfo;
use App\LocationArea;
use App\Designation;
use App\Department;
use Illuminate\Validation\Rule;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class JobseekerPersonalInfoController extends Controller
{
    
    public function __construct()
    {
        $this->middleware('auth:api');
       
               
    }

    public function index()
    {
        //get all departments
        $Individual_details= JobseekerPersonalInfo::all();
        if ($Individual_details)
        {
            return response()->json([
                'success' => true,
                'personal_details' => $Individual_details
            ]);
        }
        else{
                return response()->json([
                    'success' => false,
                    'message' => 'Sorry,no data found'
                ], 500);
            }

    }

 
    public function store(Request $request)
    {
 

      //  return $request;
        $user= auth('api')->user();
        $rules = array(
            'first_name' => 'required',
            'date_of_b' => 'required',         
            'marital_status' => 'required',         
            'nationalities_at_birth' => 'required',           
            'date_of_b' => 'required',           
            'gender' => 'required',           
            'mobile_no' => 'required',           

            
        );
        $messages=array(
            'first_name.required' => 'Please enter a Name.',
            'date_of_b.required' => 'Please enter a Title.',        
            'marital_status.required' => 'Please select marital status.',            
            'nationalities_at_birth.required' => 'Please select nationality.',            
            'gender.required' => 'Please Select Gender.',            
            'mobile_no.required' => 'Please enter mobile no.',            
    

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

    



        $personal_details = new JobseekerPersonalInfo;
        $personal_details->first_name = $request->first_name;
        $personal_details->middle_name = $request->middle_name;
        $personal_details->last_name = $request->last_name;
        $personal_details->maiden_name = $request->maiden_name;
        $personal_details->date_of_b = $request->date_of_b;
        $personal_details->marital_status = $request->marital_status;
        $personal_details->nationalities_at_birth = $request->nationalities_at_birth;
        $personal_details->current_nationalities = $request->current_nationalities;
        $personal_details->permanent_residency = $request->permanent_residency;
        $personal_details->gender = $request->gender;
        $personal_details->mobile_no = $request->mobile_no;

        $personal_details->created_at   = now();
        $saved=$personal_details->save();

        if ($saved)
        {
          return response()->json([
                'success' => true,
            ], 200);
        }




    }
//end store function

public function show($id)
{
    $personal_detail = JobseekerPersonalInfo::find($id);


    if (!$personal_detail) 
    {
        return response()->json([
            'success' => false,
            'message' => 'Sorry, Personal Details with id ' . $id . ' cannot be found'
        ], 400);
    }else
    {
        return response()->json($personal_detail);
    }

}
//end show

public function update(Request $request, $id)
{
    $rules = array(
        'first_name' => 'required',
        
    );
    $messages=array(
        'first_name.required' => 'Please enter a Name.',

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
    
    $personal_detail = JobseekerPersonalInfo::find($id);
    if (!$personal_detail) {
        return response()->json([
            'success' => false,
            'message' => 'Sorry, Personal detail with id ' . $id . ' cannot be found'
        ], 400);
    }


    // $updated = $reference->fill($request->all())
    // ->save();

    $personal_detail->first_name = $request->first_name;
    $personal_detail->middle_name = $request->middle_name;
    $personal_detail->last_name = $request->last_name;
    $personal_detail->maiden_name = $request->maiden_name;
    $personal_detail->marital_status = $request->marital_status;
    $personal_detail->nationalities_at_birth = $request->nationalities_at_birth;
    $personal_detail->current_nationalities = $request->current_nationalities;
    $personal_detail->permanent_residency = $request->permanent_residency;
    $personal_detail->mobile_no = $request->mobile_no;

    $updated = $personal_detail->save();


    if ($updated) {
        return response()->json([
            'success' => true
        ]);
    } else {
        return response()->json([
            'success' => false,
            'message' => 'Sorry, Education could not be updated'
        ], 500);
    }




}



public function fileupload(Request $request, $id)
{

    $user = User::find($id);
    
    if ($request->hasFile('p11form')) {
        $image = $request->file('p11form');
        $name =  'P11Form_'.time().'.'.$request->photo->getClientOriginalExtension();
        $destinationPath = public_path('/img/user');
        $imagePath = $destinationPath. "/".  $name;
        $image->move($destinationPath, $name);
        $user->p11form = "/img/user/".$name;
    }
    $saved = $user->save();

     

    if($saved)
    {
        return response()->json(['success' => true, 'message' =>'Saved Successfully'], 200); 
    }else{
        return response()->json(['success' => false, 'message' =>'Oops!!'], 200);
    }

} //fileuplod fun end



public function photoFileupload(Request $request, $id)
{

    $user = User::find($id);
    
    if ($request->hasFile('coverLetter')) {
        $image = $request->file('coverLetter');
        $name =  'Cover_letter_'.time().'.'.$request->coverLetter->getClientOriginalExtension();
        $destinationPath = public_path('/img/user');
        $imagePath = $destinationPath. "/".  $name;
        $image->move($destinationPath, $name);
        $user->coverLetter = "/img/user/".$name;
    }
    $saved = $user->save();

     

    if($saved)
    {
        return response()->json(['success' => true, 'message' =>'Saved Successfully'], 200); 
    }else{
        return response()->json(['success' => false, 'message' =>'Oops!!'], 200);
    }

} //fileuplod fun end

}

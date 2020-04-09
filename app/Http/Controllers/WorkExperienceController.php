<?php

namespace App\Http\Controllers;
use App\WorkExperience;
use Validator;
use Illuminate\Http\Request;

class WorkExperienceController extends Controller
{
    public function index()
    {
        //get all work experience
        $all_experience = WorkExperience::all();
        if ($all_experience)
        {
            return response()->json([
                'success' => true,
                'experiences' => $all_experience
            ]);
        }
        else{
                return response()->json([
                    'success' => false,
                    'message' => 'Sorry,no Experiencee found'
                ], 500);
            }

    }
   


    public function store(Request $request)
    {
        
      //  return $request;
        $user= auth('api')->user();
        $rules = array(
            'employer_name' => 'required',
            'job_title' => 'required',                              
        );
        $messages=array(
            'employer_name.required' => 'Employer Name required',
            'job_title.required' => 'Please enter a Title.',           
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
        $experience = new WorkExperience;
        $experience->jobseeker_id = $user->id;   
        $experience->employer_name = $request->employer_name;
        $experience->job_title = $request->job_title;  
        $experience->description_of_duties = $request->description_of_duties;  
        $experience->start_date = $request->start_date;  
        $experience->end_date = $request->end_date;    
        $experience->country_name = $request->country_name;  
        $experience->type_of_business = $request->type_of_business;  
        $experience->un_experience = $request->un_experience;     
        $experience->unhcr_experience = $request->unhcr_experience;     
        $experience->contract_type = $request->contract_type;     
        $experience->un_unhcr_grade = $request->un_unhcr_grade;     
        $experience->msrp_id = $request->msrp_id;     
        $experience->index_id = $request->index_id;     

        $experience->created_at   = now();
        $saved=$experience->save();

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
        $experience = WorkExperience::find($id);


        if (!$experience) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Experience with id ' . $id . ' cannot be found'
            ], 400);
        }else
        {
            return response()->json($experience);
        }

    }
    //end show

    
    public function update(Request $request, $id)
    {
        $rules = array(
            'employer_name' => 'required',
            'job_title' => 'required',                              
        );
        $messages=array(
            'employer_name.required' => 'Employer Name required',
            'job_title.required' => 'Please enter a Title.',           
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
        
        $experience = WorkExperience::find($id);
        if (!$experience) {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Experience with id ' . $id . ' cannot be found'
            ], 400);
        }


        // $updated = $reference->fill($request->all())
        // ->save();
        
        $experience->employer_name = $request->employer_name;
        $experience->job_title = $request->job_title;  
        $experience->description_of_duties = $request->description_of_duties;  
        $experience->start_date = $request->start_date;  
        $experience->end_date = $request->end_date;    
        $experience->country_name = $request->country_name;  
        $experience->type_of_business = $request->type_of_business;  
        $experience->un_experience = $request->un_experience;     
        $experience->unhcr_experience = $request->unhcr_experience;     
        $experience->contract_type = $request->contract_type;     
        $experience->un_unhcr_grade = $request->un_unhcr_grade;     
        $experience->msrp_id = $request->msrp_id;     
        $experience->index_id = $request->index_id;   
        $updated = $experience->save();


        if ($updated) {
            return response()->json([
                'success' => true
            ]);
        } else {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Experience could not be updated'
            ], 500);
        }




    }
}

<?php

namespace App\Http\Controllers;
use App\Education;
use Validator;
use Illuminate\Http\Request;

class EducationController extends Controller
{
    public function index()
    {
        //get all departments
        $all_education = Education::all();
        if ($all_education)
        {
            return response()->json([
                'success' => true,
                'educations' => $all_education
            ]);
        }
        else{
                return response()->json([
                    'success' => false,
                    'message' => 'Sorry,no education found'
                ], 500);
            }

    }



    public function store(Request $request)
    {
        
      //  return $request;
        $user= auth('api')->user();
        $rules = array(
            'degree_title' => 'required',
            'begin_date' => 'required',
            'end_date' => 'required',
            'level_of_education' => 'required',

            'school_name' => 'required',

            
        );
        $messages=array(
            'degree_title.required' => 'Please enter a Name.',
            'begin_date.required' => 'Please enter a Title.',
            'end_date.required' => 'Please enter a Employeer.',
            'level_of_education.required' => 'Please enter a Employeer.',

            'school_name.required' => 'Please enter a Employeer.',

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
        $education = new Education;
        $education->degree_title = $request->degree_title;
        $education->begin_date = $request->begin_date;
        $education->end_date = $request->end_date;
        $education->jobseeker_id = $user->id;
        $education->level_of_education = $request->level_of_education;
        $education->school_name = $request->school_name;
        $education->education_completed = $request->education_completed;
        $education->topics_of_study = $request->topics_of_study;
        $education->created_at   = now();

        $saved=$education->save();

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
        $education = Education::find($id);


        if (!$education) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Education with id ' . $id . ' cannot be found'
            ], 400);
        }else
        {
            return response()->json($education);
        }

    }
    //end show

    
    public function update(Request $request, $id)
    {
        $rules = array(
            'degree_title' => 'required|max:190',
            'begin_date' => 'required',
            'end_date' => 'required',
            'level_of_education' => 'required',
            'school_name' => 'required',
            
        );
        $messages=array(
            'degree_title.required' => 'Please enter a Name.',
            'begin_date.required' => 'Please enter a Title.',
            'end_date.required' => 'Please enter a Employeer.',
            'level_of_education.required' => 'Please enter a Employeer.',

            'school_name.required' => 'Please enter a Employeer.',

        
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
        
        $education = Education::find($id);
        if (!$education) {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Education with id ' . $id . ' cannot be found'
            ], 400);
        }


        // $updated = $reference->fill($request->all())
        // ->save();

        $education->degree_title = $request->degree_title;
        $education->begin_date = $request->begin_date;
        $education->end_date = $request->end_date;
        $education->level_of_education = $request->level_of_education;
        $education->school_name = $request->school_name;
        $education->education_completed = $request->education_completed;
        $education->topics_of_study = $request->topics_of_study;
        $updated = $education->save();


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

}

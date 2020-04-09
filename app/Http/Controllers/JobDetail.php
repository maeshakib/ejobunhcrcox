<?php

namespace App\Http\Controllers;
use App\JobPost;

use Illuminate\Http\Request;

class JobDetail extends Controller
{
    public function index()
    {
        //get all job to show data in Job Board
        $job_applied = JobPost::all();
        if ($job_applied)
        {
            return response()->json([
                'success' => true,
                'all_jobs' => $job_applied
            ]);
        }
        else{
                return response()->json([
                    'success' => false,
                    'message' => 'Sorry,no Job found'
                ], 500);
            }

    } //end index function


   // show single job data in Job Board

    public function show($id)
    {
        $job = JobPost::find($id);


        if (!$job) 
        {
            return response()->json([
                'success' => false,
                'message' => 'Sorry, Job with id ' . $id . ' cannot be found'
            ], 400);
        }else
        {
            return response()->json($job);
        }

    }
}

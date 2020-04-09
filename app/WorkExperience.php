<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class WorkExperience extends Model
{
    protected $table='work_experiences';
    protected $fillable = [
        'jobseeker_id', 'employer_name','job_title'
    ];

}

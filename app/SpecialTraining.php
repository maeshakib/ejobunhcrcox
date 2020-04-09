<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class SpecialTraining extends Model
{
    protected $table='special_trainings';
    protected $fillable = [
        'course_title', 'school_name','country','course_start_date','topic_area','training_methodology','course_description	'
    ];
}

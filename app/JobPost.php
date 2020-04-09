<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class JobPost extends Model
{
    protected $table='job_posts';
    protected $fillable = [
        'job_title', 'vacancy_notice', 'postition_number', 'location', 'position_grade', 'closing_date', 'organizational_context','responsibilities','accountability_and_authority','minimum_qualification'
    ];

}

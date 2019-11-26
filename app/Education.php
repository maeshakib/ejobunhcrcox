<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Education extends Model
{
    protected $table='educations';
    protected $fillable = [
        'degree_title', 'begin_date','end_date','level_of_education','school_name'
    ];
}

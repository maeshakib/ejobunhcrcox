<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Reference extends Model
{
    protected $table='jobseeker_references';
    protected $fillable = [
        'name', 'title','employeer','email'
    ];
}

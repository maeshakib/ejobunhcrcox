<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class JobseekerPersonalInfo extends Model
{
    protected $table='users';
    protected $fillable = [
        'name', 'email','first_name','role_id','created_at','updated_at'
    ];
}

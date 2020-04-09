<?php

namespace App;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Tymon\JWTAuth\Contracts\JWTSubject;
use Illuminate\Database\Eloquent\SoftDeletes;

class User extends Authenticatable implements JWTSubject
{
    use SoftDeletes;

    use Notifiable;
    /**
     * The attributes that are mass assignable.
     *
     * @var array
     */
    protected $fillable = [
        'email', 'password',
    ];

    /**
     * The attributes that should be hidden for arrays.
     *
     * @var array
     */
    protected $hidden = [
        'password', 'remember_token',
    ];

    public function getJWTIdentifier()
    {
        return $this->getKey();
    }

    /**
     * Return a key value array, containing any custom claims to be added to the JWT.
     *
     * @return array
     */
    public function getJWTCustomClaims()
    {
        return [];
    }

    public function role()
    {
        return $this->belongsTo(Role::class);
    }

    public function designation()
    {
        return $this->belongsTo(Designation::class);
    }
    public function department()
    {
        return $this->belongsTo(Department::class, 'department_id');
    }
    public function location_area()
    {
        return $this->belongsTo(LocationArea::class, 'location_area_id');
    }

    //user supervisor_relation
    public function my_employees()
    {
        return $this->hasMany('App\User', 'supervisor_id');
    }

    public function my_manager()
    {
        return $this->belongsTo('App\User', 'supervisor_id');

    }

    //user supervisor_relation
    public function attendance()
    {
        return $this->hasMany('App\UserAttendance');

    }

    public function clients()
    {
        return $this->hasMany('App\Client');
    }
    public function sales()
    {
        return $this->hasMany('App\Sale');
    }
    public function collections()
    {
        return $this->hasMany('App\Collection');
    }

    public function targets()
    {
        return $this->hasMany('App\Target');
    }
    public function sales_target()
    {
        return $this->hasMany('App\Target')->where('type', 0);
    }
    public function collection_target()
    {
        return $this->hasMany('App\Target')->where('type', 1);
    }
    public function depot()
    {
        return $this->belongsTo(Depot::class, 'depot_id');
    }

    //
    public function educations()
    {
        return $this->hasMany('App\Education');
    }
    public function work_experiences()
    {
        return $this->hasMany('App\WorkExperience');
    }
  
}

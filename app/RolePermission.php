<?php

namespace App;

use App\Permission;
use Illuminate\Database\Eloquent\Model;

class RolePermission extends Model
{
    protected $table = 'role_permissions';
    public $timestamps = false;
    protected $guarded = array('id');

    public function role()
    {
        return $this->belongsTo(Role::class);
    }

    public function permission()
    {
        return $this->belongsTo(Permission::class);
    }
}

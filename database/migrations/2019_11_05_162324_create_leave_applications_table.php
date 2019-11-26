<?php

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateLeaveApplicationsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('leave_applications', function (Blueprint $table) {
            $table->increments('id');
            $table->string('reason', 150);
            $table->text('description')->nullable();
            $table->text('remarks')->nullable();
            $table->unsignedInteger('user_id');
            $table->unsignedInteger('leave_id');
            $table->unsignedInteger('fiscal_year_id')->nullable();
            $table->date('from_date');
            $table->date('to_date');
            $table->integer('total_days');
            $table->unsignedInteger('approved_by')->nullable();
            $table->tinyInteger('is_approved')->default(0);
            $table->text('file')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('leave_applications');
    }
}

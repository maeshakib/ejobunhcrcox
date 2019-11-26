<?php

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateMeetingParticipantsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('meeting_participants', function (Blueprint $table) {
            $table->increments('id');
            $table->unsignedInteger('meeting_id');
            $table->string('user_email', 191);
            $table->text('name')->nullable();
            $table->tinyInteger('accept_status')->default(0);
            $table->tinyInteger('attended')->default(0);
            $table->tinyInteger('is_owner')->default(0);
            $table->text('comment')->nullable();
            $table->timestamps();

            $table->foreign('meeting_id')->references('id')->on('meetings')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('meeting_participants');
    }
}

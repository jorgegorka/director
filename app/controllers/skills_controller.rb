class SkillsController < ApplicationController
  before_action :require_company!
  before_action :set_skill, only: [ :show, :edit, :update, :destroy ]

  def index
    @skills = Current.company.skills.order(:name)
    @skills = @skills.by_category(params[:category]) if params[:category].present?
    @current_category = params[:category]
    @categories = Current.company.skills.where.not(category: [ nil, "" ]).distinct.pluck(:category).sort
  end

  def show
    @agents = @skill.agents.order(:name)
  end

  def new
    @skill = Current.company.skills.new(builtin: false)
  end

  def create
    @skill = Current.company.skills.new(skill_params)
    @skill.builtin = false

    if @skill.save
      redirect_to @skill, notice: "#{@skill.name} skill has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @skill.update(skill_params)
      redirect_to @skill, notice: "#{@skill.name} skill has been updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @skill.builtin?
      redirect_to @skill, alert: "Built-in skills cannot be deleted."
      return
    end

    name = @skill.name
    @skill.destroy
    redirect_to skills_path, notice: "#{name} skill has been deleted."
  end

  private

  def set_skill
    @skill = Current.company.skills.find(params[:id])
  end

  def skill_params
    params.require(:skill).permit(:key, :name, :description, :markdown, :category)
  end
end
